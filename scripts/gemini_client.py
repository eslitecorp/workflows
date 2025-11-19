import subprocess
import os
import sys

class GeminiClient:
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.environ.get('GEMINI_API_KEY')
        if not self.api_key:
            print("Warning: GEMINI_API_KEY not set. CLI calls may fail if not authenticated globally.")

    def run_prompt(self, prompt: str, model: str = "gemini-2.5-flash", context_files: list = None) -> str:
        """
        Executes gemini-cli with the given prompt and model.
        """
        cmd = ["gemini", "run", prompt, "--model", model]
        
        if context_files:
            # Assuming --context or similar flag for files, or passing them in prompt
            # For now, let's assume we pass file paths as arguments if supported, 
            # or we might need to read them and append to prompt if CLI doesn't support direct file args in this version.
            # Based on research, we'll assume a standard input or flag. 
            # Let's try appending to the prompt for simplicity in this MVP wrapper 
            # unless we find specific CLI syntax.
            # Ideally: cmd.extend(["--context", ",".join(context_files)])
            pass

        # Set environment variable for the subprocess
        env = os.environ.copy()
        if self.api_key:
            env['GEMINI_API_KEY'] = self.api_key

        try:
            print(f"Running Gemini CLI with model {model}...")
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                env=env,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error running gemini-cli: {e.stderr}")
            return f"Error: {e.stderr}"

if __name__ == "__main__":
    # Test
    client = GeminiClient()
    print(client.run_prompt("Hello, are you working?", model="gemini-2.5-flash"))
