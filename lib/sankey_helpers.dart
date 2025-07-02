// lib/sankey_helpers.dart

import 'package:flutter/material.dart';
import 'package:sankey_flutter/sankey.dart';
import 'package:sankey_flutter/sankey_node.dart';
import 'package:sankey_flutter/sankey_link.dart';
import 'package:sankey_flutter/interactive_sankey_painter.dart';

/// Generates a configured [Sankey] layout engine
///
/// The [width] and [height] parameters define the drawing area dimensions
/// [nodeWidth] is the width of each node, and [nodePadding] sets the space between nodes
/// The returned [Sankey] object is pre-configured with the specified dimensions and
/// properties for use in computing the layout
///
/// Example:
/// ```dart
/// final sankey = generateSankeyLayout(
///   width: 1000,
///   height: 600,
///   nodeWidth: 20,
///   nodePadding: 15,
/// );
/// ```
Sankey generateSankeyLayout({
  double width = 1000,
  double height = 600,
  double nodeWidth = 20,
  double nodePadding = 15,
}) {
  return Sankey()
    ..nodeWidth = nodeWidth
    ..nodePadding = nodePadding
    ..x0 = 0
    ..y0 = 0
    ..x1 = width
    ..y1 = height;
}

/// A default palette of 15 visually distinct colors for use in node theming
///
/// These colors can be automatically assigned to nodes if no custom color is provided
const List<Color> defaultNodeColors = [
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.deepOrange,
  Colors.redAccent,
  Colors.indigoAccent,
  Colors.red,
  Colors.teal,
  Colors.indigo,
  Colors.brown,
  Colors.grey,
  Colors.deepPurple,
  Colors.pink,
  Colors.amber,
  Colors.lightBlue,
];

/// Utility class for managing node theming
///
/// This class provides methods to retrieve a node's color and contrast text color
/// based on its label. If a custom color is not specified in [nodeColors], a color
/// from [defaultNodeColors] is chosen based on a hash of the node's label
class SankeyNodeThemeManager {
  final Map<String, Color> nodeColors;

  SankeyNodeThemeManager(this.nodeColors);

  /// Returns the color associated with the given [label]
  ///
  /// If no custom color is defined for [label], it selects a default color
  /// from [defaultNodeColors] using a hash
  Color getColor(String label) {
    return nodeColors[label] ??
        defaultNodeColors[label.hashCode % defaultNodeColors.length];
  }

  /// Returns an appropriate text color (white or black) for the background color
  /// assigned to the given [label] to ensure legible contrast
  Color getTextColor(String label) {
    final background = getColor(label);
    final isDark = background.computeLuminance() < 0.05;
    return isDark ? Colors.white : Colors.black;
  }
}

/// Generates a default node color map for a list of [SankeyNode] objects
///
/// Each node's [label] is used to assign a color from [defaultNodeColors] in sequence
/// (cycling through the palette). This is useful as a convenience method when no
/// custom node colors are provided
///
/// Returns a [Map] with the node label as key and the assigned [Color] as value
Map<String, Color> generateDefaultNodeColorMap(List<SankeyNode> nodes) {
  final Map<String, Color> colorMap = {};
  for (int i = 0; i < nodes.length; i++) {
    final label = nodes[i].label;
    if (label != null && !colorMap.containsKey(label)) {
      colorMap[label] = defaultNodeColors[i % defaultNodeColors.length];
    }
  }
  return colorMap;
}

/// Determines if a tap hit a node and returns its [id]; returns null if no node is hit
///
/// [nodes] is the list of [SankeyNode] objects and [tapPos] is the [Offset] of
/// the tap event in the canvas coordinate space
int? detectTappedNode(List<SankeyNode> nodes, Offset tapPos) {
  for (var node in nodes) {
    final rect =
        Rect.fromLTWH(node.x0, node.y0, node.x1 - node.x0, node.y1 - node.y0);
    if (rect.contains(tapPos)) return node.id;
  }
  return null;
}

/// Determines if a tap hit a link and returns that [SankeyLink]; null otherwise.
///
/// Reconstructs each link’s Path the same way the painters do, then checks
/// if the tap point lies within the path’s stroke bounds.
SankeyLink? detectTappedLink(List<SankeyLink> links, Offset tapPos) {
  for (var link in links) {
    final source = link.source as SankeyNode;
    final target = link.target as SankeyNode;

    // Build the same cubic path
    final path = Path()..moveTo(source.x1, link.y0);
    final xMid = (source.x1 + target.x0) / 2;
    path.cubicTo(xMid, link.y0, xMid, link.y1, target.x0, link.y1);

    // Inflate the path’s bounds by half the stroke width for hit‐tolerance
    final hitBounds = path.getBounds().inflate(link.width / 2);
    if (!hitBounds.contains(tapPos)) continue;

    // Lightweight acceptance: bounds test is sufficient for thin strokes.
    return link;
  }
  return null;
}

/// Combines nodes and links with layout logic
///
/// The [SankeyDataSet] class holds the list of nodes and links, and provides a
/// [layout] method that applies the given [Sankey] layout generator to compute
/// the positions and dimensions for the nodes and links
class SankeyDataSet {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;

  SankeyDataSet({required this.nodes, required this.links});

  /// Computes the layout for the nodes and links using the provided [sankey] generator.
  void layout(Sankey sankey) {
    sankey.layout(nodes, links);
  }
}

/// Builds an interactive painter based on the provided nodes, links, and node colors
///
/// The [selectedNodeId] parameter indicates an optional node ID for which
/// special highlighting may be applied.
/// Returns an instance of [InteractiveSankeyPainter].
InteractiveSankeyPainter buildInteractiveSankeyPainter({
  required List<SankeyNode> nodes,
  required List<SankeyLink> links,
  required Map<String, Color> nodeColors,
  int? selectedNodeId,
  final bool showLabels = true,
}) {
  return InteractiveSankeyPainter(
    nodes: nodes,
    links: links,
    nodeColors: nodeColors,
    selectedNodeId: selectedNodeId,
    showLabels: showLabels,
  );
}

/// A widget that wraps an interactive Sankey diagram
///
/// The [SankeyDiagramWidget] integrates gesture detection for tapping nodes and links,
/// renders the diagram using a [CustomPaint], and exposes callbacks when a node or link is tapped.
class SankeyDiagramWidget extends StatelessWidget {
  final SankeyDataSet data;
  final Map<String, Color> nodeColors;
  final int? selectedNodeId;
  final Function(int?)? onNodeTap;
  final Function(SankeyLink)? onLinkTap;
  final Size size;
  final bool showLabels;

  const SankeyDiagramWidget({
    Key? key,
    required this.data,
    required this.nodeColors,
    this.selectedNodeId,
    this.onNodeTap,
    this.onLinkTap,
    this.size = const Size(1000, 600),
    this.showLabels = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final local = details.localPosition;

        // 1) Try link first
        if (onLinkTap != null) {
          final link = detectTappedLink(data.links, local);
          if (link != null) {
            onLinkTap!(link);
            return;
          }
        }

        // 2) Fallback to node
        final nodeId = detectTappedNode(data.nodes, local);
        if (onNodeTap != null) {
          onNodeTap!(nodeId);
        }
      },
      child: CustomPaint(
        size: size,
        painter: buildInteractiveSankeyPainter(
          nodes: data.nodes,
          links: data.links,
          nodeColors: nodeColors,
          selectedNodeId: selectedNodeId,
          showLabels: showLabels,
        ),
      ),
    );
  }
}
