import shap
import matplotlib
matplotlib.use('Agg') # Use backend non-GUI
import matplotlib.pyplot as plt
import io
import uuid
from datetime import datetime
from lime.lime_tabular import LimeTabularExplainer
from db.database import supabase

IMAGE_BUCKET = "heart-prediction-xai-reports" 

def upload_plot(figure, folder_name, request_id):
    # Path: {folder_name}/{request_id}/{random_id}.png
    buf = io.BytesIO()
    figure.savefig(buf, format="png", bbox_inches="tight", dpi=100)
    buf.seek(0)
    
    filename = f"{folder_name}/{request_id}/{uuid.uuid4()}.png"
    
    try:
        supabase.storage.from_(IMAGE_BUCKET).upload(
            path=filename,
            file=buf.getvalue(),
            file_options={"content-type": "image/png"}
        )
        return supabase.storage.from_(IMAGE_BUCKET).get_public_url(filename)
    except Exception as e:
        print(f"Upload Error ({folder_name}): {str(e)}")
        return None
    finally:
        plt.close(figure) # Giải phóng RAM

def generate_patient_xai_images(model, background_data, lime_train_data, features_list, processed_df, raw_row):
    # Tạo ID chung
    request_id = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:6]}"
    results = {}

    # --- CHUẨN BỊ SHAP VALUES ---
    try:
        explainer = shap.Explainer(model, background_data.data)
        shap_values = explainer(processed_df)
        shap_values.display_data = raw_row.values
    except Exception as e:
        print(f"Error calculate SHAP values: {e}")
        return results

    # --- BIỂU ĐỒ 1: SHAP WATERFALL ---
    try:
        fig = plt.figure(figsize=(8, 6))
        shap.plots.waterfall(shap_values[0], show=False)
        plt.title("Patient's Risk Factor Breakdown", fontsize=14)
        results["shap_waterfall"] = upload_plot(fig, "shap", request_id)
    except Exception: pass

    # --- BIỂU ĐỒ 2: SHAP BAR ---
    try:
        fig = plt.figure(figsize=(8, 6))
        shap.plots.bar(shap_values[0], show=False) 
        plt.title("Top Factors Influencing This Prediction", fontsize=14)
        results["shap_bar"] = upload_plot(fig, "shap", request_id)
    except Exception: pass

    # --- BIỂU ĐỒ 3: LIME ---
    try:
        lime_explainer = LimeTabularExplainer(
            training_data=lime_train_data,
            feature_names=features_list,
            class_names=['Normal', 'Heart Disease'],
            mode='classification',
            verbose=False
        )
        exp = lime_explainer.explain_instance(
            data_row=processed_df.iloc[0].values,
            predict_fn=model.predict_proba
        )
        fig = exp.as_pyplot_figure()
        fig.set_size_inches(8, 6)
        plt.title("Patient's Feature Impact on Probability (LIME Analysis)", fontsize=14)
        results["lime"] = upload_plot(fig, "lime", request_id)
    except Exception: pass

    return results

def generate_batch_xai_images(model, background_data, processed_batch_df):
    request_id = f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:6]}"
    results = {}

    try:
        explainer = shap.Explainer(model, background_data.data)
        shap_values = explainer(processed_batch_df)
    except Exception as e:
        print(f"Error batch SHAP: {e}")
        return results
    
    # --- BIỂU ĐỒ 1: SHAP BAR (Global - Trung bình ảnh hưởng của nhóm này) ---
    try:
        fig = plt.figure(figsize=(10, 6))
        shap.plots.bar(shap_values, show=False, max_display=15) 
        plt.title("Group Average Feature Importance", fontsize=14)
        results["batch_shap_bar"] = upload_plot(fig, "shap", request_id)
    except Exception as e:
        print(f"Batch bar error: {e}")

    # --- BIỂU ĐỒ 2: SHAP BEESWARM (Global) ---
    try:
        fig = plt.figure(figsize=(10, 6))
        shap.plots.beeswarm(shap_values, show=False, max_display=15)
        plt.title("Group Risk Distribution", fontsize=14)
        results["batch_shap_beeswarm"] = upload_plot(fig, "shap", request_id)
    except Exception as e: 
        print(f"Beeswarm error: {e}")

    return results