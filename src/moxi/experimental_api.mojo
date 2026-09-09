"""Focused opt-in path for experimental integrations."""

from .capability_types import (
    CapabilityApproval,
    CapabilityDescriptor,
    CapabilityInvocation,
    CapabilityResult,
)
from .capability_bus import CapabilityBus
from .conversation import ChatMessage, ConversationContext
from .coretext import MacOSTextShaper
from .fractal import FractalGeometry, FractalSegment, FractalState
from .harfbuzz import HarfBuzzTextShaper
from .metal import MacOSMetalCanvasPainter, MacOSMetalRenderer, MacOSMetalWindow
