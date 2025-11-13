# Use the official Python image as a base
FROM python:3.9-slim-buster

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY .

# Expose the port that the application will listen on
# Cloud Run typically expects applications to listen on port 8080
ENV PORT 8080

# Run the application
# For a simple script, you might run it directly
# If you were using a web framework (e.g., Flask, FastAPI), you\'d use gunicorn or uvicorn
CMD ["python", "main.py"]
