"""Bounded, transport-neutral conversation context for capability adapters."""

from std.collections import List

from .capability import CapabilityResult, json_quote


struct ChatMessage(ImplicitlyCopyable):
    """One role/content record in a conversation boundary."""

    var role: String
    var content: String

    def __init__(out self, role: String, content: String):
        self.role = role
        self.content = content


struct ConversationContext:
    """History that can be injected with fresh application state per turn."""

    var history: List[ChatMessage]

    def __init__(out self):
        self.history = List[ChatMessage]()

    def append_turn(mut self, role: String, content: String):
        """Append a user, assistant, tool, or system message."""
        self.history.append(ChatMessage(role, content))

    def append_capability_result(mut self, result: CapabilityResult):
        """Append a structured tool result without losing recovery metadata."""
        var content = String("{\"request_id\":")
        content += json_quote(result.request_id)
        content += ",\"status\":"
        content += String(result.status)
        content += ",\"executed\":"
        content += "true" if result.executed else "false"
        content += ",\"replayed\":"
        content += "true" if result.replayed else "false"
        content += ",\"output\":"
        content += json_quote(result.output)
        content += ",\"error_code\":"
        content += json_quote(result.error_code)
        content += ",\"recovery_hint\":"
        content += json_quote(result.recovery_hint)
        content += "}"
        self.append_turn("tool", content)

    def count(self) -> Int:
        return len(self.history)

    def message(self, index: Int) -> ChatMessage:
        return self.history[index]

    def clear(mut self):
        """Drop historical turns while preserving the context object."""
        self.history = List[ChatMessage]()

    def turn_payload(self, active_application_state: String) -> String:
        """Build a fresh JSON-shaped turn payload with current state first."""
        var payload = String("[")
        payload += "{\"role\":\"system\",\"content\":"
        payload += json_quote(active_application_state)
        payload += "}"
        for index in range(len(self.history)):
            payload += ","
            var message = self.history[index]
            payload += "{\"role\":"
            payload += json_quote(message.role)
            payload += ",\"content\":"
            payload += json_quote(message.content)
            payload += "}"
        payload += "]"
        return payload
