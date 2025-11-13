from google.adk.agents import LlmAgent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

def check_service_status(service_name: str) -> str:
    """Simulates checking the status of a given service."""
    if service_name.lower() == "web_server":
        return "Web server is running and healthy."
    elif service_name.lower() == "database":
        return "Database is running but with high latency."
    else:
        return f"Service '{service_name}' not found."


devops_agent = LlmAgent(
    model="gemini-2.5-flash",
    name="DevOpsAssistant",
    description="Assists with common DevOps tasks like checking service status.",
    instruction="""You are a DevOps assistant. You can check the status of services.
When a user asks about the status of a service:
1. Identify the service name from the user's query.
2. Use the `check_service_status` tool to get the status.
3. Respond clearly to the user with the service status.
Example Query: "What's the status of the web server?"
Example Response: "Web server is running and healthy."
""",
    tools=[check_service_status],
    output_key="devops_result"
)

if __name__ == "__main__":
    session_service = InMemorySessionService()
    session = session_service.create_session(
        app_name="devops_app",
        user_id="user123",
        session_id="session001"
    )

    runner = Runner(
        agent=devops_agent,
        app_name="devops_app",
        session_service=session_service
    )

    print("DevOps Assistant is ready. Type 'exit' to quit.")
    while True:
        user_input = input("You: ")
        if user_input.lower() == 'exit':
            break

        content = types.Content(role='user', parts=[types.Part(text=user_input)])
        events = runner.run(user_id="user123", session_id="session001", new_message=content)

        for event in events:
            if event.is_final_response() and event.content:
                print(f"DevOps Assistant: {event.content.parts[0].text}")
