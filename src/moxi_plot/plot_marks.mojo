"""Plot mark-kind tag constants shared by `Plot`, `PlotSpec`, and rendering."""


comptime PLOT_LINE = 1
comptime PLOT_SCATTER = 2
comptime PLOT_BAR = 3
comptime PLOT_DOT = 4
comptime PLOT_AREA = 5
comptime PLOT_RULE = 6
comptime PLOT_ERROR_BAR = 7
comptime PLOT_RECT = 8
comptime PLOT_TEXT = 9
comptime PLOT_STEP = 10
comptime PLOT_TICK = 11
comptime PLOT_INTERVAL = 12
comptime PLOT_BUBBLE = 13
comptime PLOT_BAND = 14
comptime PLOT_COLUMN = 15
comptime PLOT_HISTOGRAM = 16
comptime PLOT_DENSITY = 17
comptime PLOT_ECDF = 18
comptime PLOT_BOX = 19
comptime PLOT_HEATMAP = 20
comptime PLOT_HEXBIN = 21
comptime PLOT_REGRESSION = 22

# The catalog lane uses the same row-oriented Plot/PlotSpec value boundary as
# the core marks.  These constants intentionally keep catalog names distinct
# so a consumer can round-trip a mark without pretending that a generic point
# is an upstream-specific implementation.
comptime PLOT_GROUPED_BAR = 23
comptime PLOT_STACKED_BAR = 24
comptime PLOT_PIE = 25
comptime PLOT_DONUT = 26
comptime PLOT_LOLLIPOP = 27
comptime PLOT_WATERFALL = 28
comptime PLOT_CANDLESTICK = 29
comptime PLOT_BULLET = 30
comptime PLOT_GANTT = 31
comptime PLOT_SPAN_CHART = 32
comptime PLOT_BEESWARM = 33
comptime PLOT_VIOLIN = 34
comptime PLOT_RIDGELINE = 35
comptime PLOT_NIGHTINGALE = 36
comptime PLOT_POLAR = 37
comptime PLOT_POLAR_BAR = 38
comptime PLOT_RADIALBAR = 39
comptime PLOT_GAUGE = 40
comptime PLOT_RADAR = 41
comptime PLOT_POPULATION_PYRAMID = 42
comptime PLOT_PARALLEL = 43
comptime PLOT_CONTOUR = 44
comptime PLOT_CONTOURF = 45
comptime PLOT_TRICONTOUR = 46
comptime PLOT_CORRPLOT = 47
comptime PLOT_CALENDAR_HEATMAP = 48
comptime PLOT_PUNCHCARD = 49
comptime PLOT_MARIMEKKO = 50
comptime PLOT_FUNNEL = 51
comptime PLOT_BUMP = 52
comptime PLOT_EFFECT_SCATTER = 53
comptime PLOT_ARC_DIAGRAM = 54
comptime PLOT_GRAPH = 55
comptime PLOT_SANKEY = 56
comptime PLOT_SUNBURST = 57
comptime PLOT_TREE = 58
comptime PLOT_TREEMAP = 59
comptime PLOT_BARBS = 60
comptime PLOT_CHORD = 61
comptime PLOT_STREAMGRAPH = 62
comptime PLOT_CATALOG_FIRST = PLOT_GROUPED_BAR
comptime PLOT_CATALOG_LAST = PLOT_STREAMGRAPH
