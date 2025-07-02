// example/main.dart

import 'package:flutter/material.dart';
import 'package:sankey_flutter/sankey_helpers.dart';
import 'package:sankey_flutter/sankey_link.dart';
import 'package:sankey_flutter/sankey_node.dart';

void main() {
  runApp(SankeyComplexExampleApp());
}

class SankeyComplexExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complex Sankey Diagram Example',
      home: Scaffold(
        appBar: AppBar(title: Text('Complex Sankey Diagram')),
        body: SankeyComplexDiagramWidget(),
      ),
    );
  }
}

class SankeyComplexDiagramWidget extends StatefulWidget {
  @override
  _SankeyComplexDiagramWidgetState createState() =>
      _SankeyComplexDiagramWidgetState();
}

class _SankeyComplexDiagramWidgetState
    extends State<SankeyComplexDiagramWidget> {
  late List<SankeyNode> nodes;
  late List<SankeyLink> links;
  late Map<String, Color> nodeColors;
  int? selectedNodeId;
  late SankeyDataSet sankeyDataSet;

  @override
  void initState() {
    super.initState();

    nodes = [
      SankeyNode(id: 0, label: 'Salary'),
      SankeyNode(id: 1, label: 'Freelance'),
      SankeyNode(id: 2, label: 'Investments'),
      SankeyNode(id: 3, label: 'Total Income'),
      SankeyNode(id: 13, label: 'Mandatory Expenses'),
      SankeyNode(id: 14, label: 'Discretionary Expenses'),
      SankeyNode(id: 4, label: 'Taxes'),
      SankeyNode(id: 5, label: 'Essentials'),
      SankeyNode(id: 6, label: 'Discretionary'),
      SankeyNode(id: 7, label: 'Savings'),
      SankeyNode(id: 8, label: 'Debt'),
      SankeyNode(id: 9, label: 'Investments Reinvested'),
      SankeyNode(id: 10, label: 'Healthcare'),
      SankeyNode(id: 11, label: 'Education'),
      SankeyNode(id: 12, label: 'Donations'),
    ];

    links = [
      SankeyLink(source: nodes[0], target: nodes[3], value: 70),
      SankeyLink(source: nodes[1], target: nodes[3], value: 30),
      SankeyLink(source: nodes[2], target: nodes[3], value: 20),
      SankeyLink(source: nodes[3], target: nodes[13], value: 64),
      SankeyLink(source: nodes[3], target: nodes[14], value: 56),
      SankeyLink(source: nodes[13], target: nodes[4], value: 20),
      SankeyLink(source: nodes[13], target: nodes[5], value: 40),
      SankeyLink(source: nodes[13], target: nodes[10], value: 3),
      SankeyLink(source: nodes[13], target: nodes[11], value: 1),
      SankeyLink(source: nodes[14], target: nodes[6], value: 20),
      SankeyLink(source: nodes[14], target: nodes[7], value: 20),
      SankeyLink(source: nodes[14], target: nodes[8], value: 10),
      SankeyLink(source: nodes[14], target: nodes[9], value: 5),
      SankeyLink(source: nodes[14], target: nodes[12], value: 1),
    ];

    nodeColors = generateDefaultNodeColorMap(nodes);
    sankeyDataSet = SankeyDataSet(nodes: nodes, links: links);
    final sankey = generateSankeyLayout(
      width: 1000,
      height: 600,
      nodeWidth: 20,
      nodePadding: 15,
    );
    sankeyDataSet.layout(sankey);
  }

  /// Walks fully upstream & downstream, choosing the highest-value branch
  List<SankeyLink> _buildFullChain(SankeyLink tapped) {
    final chain = <SankeyLink>[];

    // 1) Go upstream: from tapped.source back to any true source
    var current = tapped;
    while (true) {
      final incoming = (current.source as SankeyNode).targetLinks;
      if (incoming.isEmpty) break;
      // pick the link with the largest value
      final bestUp = incoming.reduce((a, b) => a.value >= b.value ? a : b);
      chain.insert(0, bestUp);
      current = bestUp;
    }

    // 2) Add the tapped link itself
    chain.add(tapped);

    // 3) Go downstream: from tapped.target forward to any true sink
    current = tapped;
    while (true) {
      final outgoing = (current.target as SankeyNode).sourceLinks;
      if (outgoing.isEmpty) break;
      // pick the link with the largest value
      final bestDown = outgoing.reduce((a, b) => a.value >= b.value ? a : b);
      chain.add(bestDown);
      current = bestDown;
    }

    return chain;
  }

  /// Shows all links in and out of a node.
  void _handleNodeTap(int? nodeId) {
    setState(() => selectedNodeId = nodeId);

    if (nodeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tapped outside any node')));
      return;
    }

    final node = nodes.firstWhere((n) => n.id == nodeId);
    final parts = <String>[];
    node.sourceLinks.forEach((l) {
      parts.add('→ ${(l.target as SankeyNode).label} (${l.value})');
    });
    node.targetLinks.forEach((l) {
      parts.add('← ${(l.source as SankeyNode).label} (${l.value})');
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Node: ${node.label}'),
        content: Text(parts.isEmpty ? 'No links' : parts.join('\n')),
      ),
    );
  }

  /// Shows the entire chain when a link is tapped.
  void _handleLinkTap(SankeyLink link) {
    final chain = _buildFullChain(link);

    // The very first node label (upstream-most source):
    final firstSource = (chain.first.source as SankeyNode).label ?? '<unknown>';

    // Then each link’s target + its value
    final downstreamLabels = chain
        .map((l) => '${(l.target as SankeyNode).label} (${l.value})')
        .toList();

    final parts = <String>[firstSource] + downstreamLabels;
    final message = parts.join(' → ');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Link path'),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SankeyDiagramWidget(
          data: sankeyDataSet,
          nodeColors: nodeColors,
          selectedNodeId: selectedNodeId,
          onNodeTap: _handleNodeTap,
          onLinkTap: _handleLinkTap,
          size: const Size(1000, 600),
          showLabels: true,
        ),
      ),
    );
  }
}
