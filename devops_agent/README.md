# DevOps Assistant Agent

This project provides a basic DevOps assistant agent built using the Google Agent Development Kit (ADK) and the Gemini 2.5 Flash model.

## How to Develop Locally

To set up and run the DevOps Assistant locally, follow these steps:

1.  **Clone the repository (if you\'t already):**

    ```bash
    git clone <repository_url>
    cd devops_agent
    ```

2.  **Create a Python virtual environment and activate it:**

    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

3.  **Install the required dependencies:**

    ```bash
    pip install -r requirements.txt
    ```

4.  **Set up your Google API Key:**

    Ensure you have a Google Cloud project with the Gemini API enabled. Set your API key as an environment variable:

    ```bash
    export GOOGLE_API_KEY="YOUR_GEMINI_API_KEY"
    ```

    Replace `YOUR_GEMINI_API_KEY` with your actual API key.

5.  **Run the agent:**

    ```bash
    python main.py
    ```

    You can now interact with the DevOps Assistant in your terminal.

## How to Deploy to Cloud Run

To deploy the DevOps Assistant to Google Cloud Run, follow these steps:

1.  **Ensure you have the Google Cloud SDK installed and configured.**

2.  **Authenticate with Google Cloud:**

    ```bash
    gcloud auth login
    gcloud config set project YOUR_PROJECT_ID
    ```

    Replace `YOUR_PROJECT_ID` with your Google Cloud project ID.

3.  **Build the Docker image:**

    Navigate to the `devops_agent` directory and build the Docker image:

    ```bash
    cd devops_agent
    gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/devops-assistant
    ```

    Replace `YOUR_PROJECT_ID` with your Google Cloud project ID.

4.  **Deploy to Cloud Run:**

    ```bash
    gcloud run deploy devops-assistant \
      --image gcr.io/YOUR_PROJECT_ID/devops-assistant \
      --platform managed \
      --region us-central1 \
      --allow-unauthenticated \
      --set-env-vars GOOGLE_API_KEY="YOUR_GEMINI_API_KEY"
    ```

    -   Replace `YOUR_PROJECT_ID` with your Google Cloud project ID.
    -   Choose an appropriate `--region`.
    -   `--allow-unauthenticated` makes the service publicly accessible. Adjust as needed.
    -   Replace `YOUR_GEMINI_API_KEY` with your actual API key. Consider using Secret Manager for production environments.

5.  **Access the deployed service:**

    After deployment, Cloud Run will provide a URL for your service. You can access it via HTTP requests.
