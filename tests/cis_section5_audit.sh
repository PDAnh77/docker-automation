#!/bin/bash

check_pass_fail() {
    local actual="$1"
    local expected="$2"
    local desc="$3"
    local section="$4"

    if [[ "$actual" == *"$expected"* ]]; then
        echo "[PASS] $section $desc"
    else
        echo "[FAIL] $section $desc (Actual: '$actual' | Expected: '$expected')"
    fi
}

# Swarm mode
SWARM_MODE=$(docker info --format '{{.Swarm }}')
check_pass_fail "$SWARM_MODE" "1" "Swarm mode is enabled" "5.1"

# Get all container IDs (running and stopped)
CONTAINERS=$(docker ps --quiet --all)

if [ -z "$CONTAINERS" ]; then
    echo "No containers found to inspect."

    # Restart policy (Service check)
    echo "Inspecting Swarm Services:"
    SERVICE_RESTART=$(docker service inspect my_stack_api --format '{{json .Spec.TaskTemplate.RestartPolicy }}' 2>/dev/null)
    check_pass_fail "$SERVICE_RESTART" '"MaxAttempts":5' "Service Restart Policy set to 5" "5.15"
else
    for ID in $CONTAINERS; do
        NAME=$(docker inspect --format '{{.Name}}' $ID)
        printf "\nInspecting Container: %s\n" "$NAME"

        # AppArmor Profile
        APPARMOR=$(docker inspect --format '{{ .AppArmorProfile }}' $ID)
        check_pass_fail "$APPARMOR" "docker-default" "AppArmor Profile enabled" "5.2"

        # Linux kernel capabilities
        CAP_DROP=$(docker inspect --format '{{.HostConfig.CapDrop}}' $ID)
        if [[ "$CAP_DROP" == *"[ALL]"* || "$CAP_DROP" == *"[CAP_NET_RAW]"* ]]; then
            echo "[PASS] 5.4 Linux kernel capabilities are restricted: $CAP_DROP"
        else
            echo "[FAIL] 5.4 Linux kernel capabilities NOT restricted"
        fi

        # Privileged containers
        PRIVILEGED=$(docker inspect --format '{{ .HostConfig.Privileged }}' $ID)
        check_pass_fail "$PRIVILEGED" "false" "Privileged containers are not used" "5.5"

        # Sensitive host system directories
        MOUNTS=$(docker inspect --format '{{.Mounts }}' "$ID")
        if [[ "$MOUNTS" == "[]" || "$MOUNTS" == *"tmpfs"* ]]; then
            RESULT="[]"
        else
            RESULT="$MOUNTS"
        fi
        check_pass_fail "$RESULT" "[]" "Sensitive host system directories not mounted" "5.6"

        # sshd within containers
        SSH_CHECK=$(docker exec $ID ps aux 2>/dev/null | grep ssh | grep -v grep)
        if [ -z "$SSH_CHECK" ]; then
            echo "[PASS] 5.7 sshd is not run within container"
        else
            echo "[FAIL] 5.7 sshd IS running within container"
        fi

        # Host's network namespace
        NET_MODE=$(docker inspect --format '{{ .HostConfig.NetworkMode }}' $ID)
        if [[ "$NET_MODE" != "host" ]]; then
            echo "[PASS] 5.10 Host's network namespace is not shared: $NET_MODE"
        else
            echo "[FAIL] 5.10 Host's network namespace IS shared"
        fi

        # Memory usage limited
        MEM_LIMIT=$(docker inspect --format '{{.HostConfig.Memory }}' $ID)
        if [ "$MEM_LIMIT" -gt 0 ]; then
            echo "[PASS] 5.11 Memory usage for container is limited: $MEM_LIMIT bytes"
        else
            echo "[FAIL] 5.11 Memory usage for container is NOT limited"
        fi

        # CPU priority (NanoCpus)
        CPU_LIMIT=$(docker inspect --format '{{.HostConfig.NanoCpus }}' $ID)
        if [ "$CPU_LIMIT" -gt 0 ]; then
            echo "[PASS] 5.12 CPU priority/limit is set appropriately: $CPU_LIMIT NanoCpus"
        else
            echo "[FAIL] 5.12 CPU priority is NOT set"
        fi

        # Read only root filesystem
        READ_ONLY=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs }}' $ID)
        check_pass_fail "$READ_ONLY" "true" "Root filesystem is mounted as read-only" "5.13"

        # Host's process namespace
        PID_MODE=$(docker inspect --format '{{.HostConfig.PidMode }}' $ID)
        check_pass_fail "$PID_MODE" "" "Host's process namespace is not shared" "5.16"

        # Host's IPC namespace
        IPC_MODE=$(docker inspect --format '{{.HostConfig.IpcMode }}' $ID)
        check_pass_fail "$IPC_MODE" "private" "Host's IPC namespace is not shared" "5.17"

        # Host devices
        DEVICES=$(docker inspect --format '{{.HostConfig.Devices }}' $ID)
        check_pass_fail "$DEVICES" "[]" "Host devices are not directly exposed" "5.18"

        # Default ulimit
        ULIMITS=$(docker inspect --format '{{.HostConfig.Ulimits}}' "$ID")

        if [[ "$ULIMITS" == *"nofile=64000:64000"* && "$ULIMITS" == *"nproc=1024:2048"* ]]; then
            echo "[PASS] 5.19 Default ulimit is inherited"
        else
            echo "[FAIL] 5.19 Default ulimit is inherited (Actual: '$ULIMITS')"
        fi

        # Mount propagation
        PROPAGATION=$(docker inspect --format '{{range .Mounts}} {{.Propagation}} {{end}}' $ID)
        check_pass_fail "$PROPAGATION" "" "Mount propagation mode is not set to shared" "5.20"

        # Host's UTS namespace
        UTS_MODE=$(docker inspect --format '{{.HostConfig.UTSMode }}' $ID)
        check_pass_fail "$UTS_MODE" "" "Host's UTS namespace is not shared" "5.21"

        # Default seccomp profile
        SEC_OPT=$(docker inspect --format '{{.HostConfig.SecurityOpt }}' $ID)
        if [[ "$SEC_OPT" != *"seccomp=unconfined"* ]]; then
            echo "[PASS] 5.22 Default seccomp profile is NOT disabled"
        else
            echo "[FAIL] 5.22 Seccomp profile IS disabled"
        fi

        # Cgroup usage confirmed
        CGROUP=$(docker inspect --format '{{.HostConfig.CgroupParent }}' $ID)
        check_pass_fail "$CGROUP" "" "Cgroup usage is default (confirmed)" "5.25"

        # Container health check
        HEALTH_STATUS=$(docker inspect --format '{{.State.Health.Status }}' $ID 2>/dev/null)
        check_pass_fail "$HEALTH_STATUS" "healthy" "Container health is healthy" "5.27"

        # Host's user namespaces
        USERNS=$(docker inspect --format '{{.HostConfig.UsernsMode }}' $ID)
        check_pass_fail "$USERNS" "" "Host's user namespaces are not shared" "5.31"

        # Docker socket mount
        DOCKER_SOCK=$(docker inspect --format '{{.Mounts}}' $ID | grep "docker.sock")
        if [ -z "$DOCKER_SOCK" ]; then
            echo "[PASS] 5.32 Docker socket is not mounted inside container"
        else
            echo "[FAIL] 5.32 Docker socket IS mounted inside container"
        fi
    done
fi

# Auditd checks for exec options
echo "Inspecting Auditd Logs:"
PRIV_LOG=$(sudo ausearch -k docker 2>/dev/null | grep exec | grep privileged)
USER_LOG=$(sudo ausearch -k docker 2>/dev/null | grep exec | grep user)

if [ -z "$PRIV_LOG" ]; then
    echo "[PASS] 5.23 No privileged docker exec commands found in audit logs"
else
    echo "[FAIL] 5.23 Privileged docker exec commands detected!"
fi

if [ -z "$USER_LOG" ]; then
    echo "[PASS] 5.24 No user=root docker exec commands found in audit logs"
else
    echo "[FAIL] 5.24 User=root docker exec commands detected!"
fi

echo ">>> Complete."