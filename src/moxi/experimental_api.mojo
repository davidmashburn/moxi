"""Focused opt-in path for experimental integrations."""

from .capability import (
    CapabilityApproval,
    CapabilityBus,
    CapabilityDescriptor,
    CapabilityInvocation,
    CapabilityResult,
)
from .conversation import ChatMessage, ConversationContext
from .coretext import MacOSTextShaper
from .fractal import FractalGeometry, FractalSegment, FractalState
from .harfbuzz import HarfBuzzTextShaper
from .metal import MacOSMetalCanvasPainter, MacOSMetalRenderer, MacOSMetalWindow
