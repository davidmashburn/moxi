"""Conversation context turn-boundary contract test."""

from moxi import test_check
from moxi import CAPABILITY_REQUIRES_APPROVAL, CapabilityResult, ConversationContext


def main():
    var context = ConversationContext()
    context.append_turn("user", "Show the panel")
    context.append_turn("tool", "wx.submit accepted")
    test_check(context.count() == 2)
    test_check(context.message(0).role == "user")
    var payload = context.turn_payload("remember_name:true")
    test_check(payload.startswith("[{\"role\":\"system\""))
    test_check("remember_name:true" in payload)
    test_check("wx.submit accepted" in payload)
    var blocked = CapabilityResult(
        "conversation-1",
        CAPABILITY_REQUIRES_APPROVAL,
        "",
        "Ask the user first.",
        error_code="APPROVAL_REQUIRED",
    )
    context.append_capability_result(blocked)
    test_check("APPROVAL_REQUIRED" in context.message(2).content)
    test_check("Ask the user first." in context.message(2).content)
    context.clear()
    test_check(context.count() == 0)
    print("Moxi conversation test passed")
