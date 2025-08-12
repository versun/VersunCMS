from tasks import example_task
import time

if __name__ == '__main__':
    print("Sending a test task to the queue...")
    result = example_task("Hello Huey!")
    print("Task sent. Waiting for result...")
    try:
        # Wait for up to 10 seconds for the result
        actual_result = result(blocking=True, timeout=10)
        print(f"SUCCESS: Got result from Huey: '{actual_result}'")
    except Exception as e:
        print(f"FAILURE: An error occurred while waiting for the result: {e}")
