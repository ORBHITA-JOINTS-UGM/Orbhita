import 'package:flutter/material.dart';

import 'blocks.dart';
import 'flow_chrome.dart';
import 'flow_extras.dart';
import 'flow_state.dart';
import 'home.dart';
import 'landing.dart';
import 'model.dart';
import 'plan.dart';
import 'plan_view.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets_basic.dart';

/// The data-driven ORBHITA prototype flow (compact / full-page mode).
class FlowApp extends StatefulWidget {
  const FlowApp({
    super.key,
    required this.model,
    required this.start,
    this.initialMessage = '',
    this.onClose,
  });

  final Model model;
  final String start;
  final String initialMessage;
  final VoidCallback? onClose;

  @override
  State<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<FlowApp> {
  late String current = widget.start;
  late FlowState state = _initial();
  String toast = '';
  bool week = false;
  final ScrollController body = ScrollController();

  FlowState _initial() {
    final s = FlowState.fresh(widget.start, widget.model.defaults);
    if (widget.initialMessage.isNotEmpty) {
      s.values['message'] = widget.initialMessage;
    }
    return s;
  }

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  void update(String key, dynamic value) => setState(() => state.values[key] = value);

  void go(String id) {
    if (!widget.model.screens.containsKey(id)) return;
    setState(() {
      current = id;
      toast = '';
    });
    if (body.hasClients) body.jumpTo(0);
  }

  void act(Map<String, dynamic> a) {
    final r = applyAction(state, a, current);
    if (r.state == null) {
      setState(() => toast = r.toast ?? '');
      return;
    }
    setState(() => state = r.state!);
    go(a['target'] as String);
  }

  @override
  Widget build(BuildContext context) {
    if (current == 'login') {
      return Landing(onContinue: () {
        setState(() => state = FlowState.fresh('home', widget.model.defaults));
        go('home');
      });
    }
    final s = widget.model.screens[current]!;
    final plan = examplePlan(state.values, state.mode, state.done);
    final ctx = BlockCtx(
      state: state,
      current: current,
      update: update,
      go: go,
      plan: plan,
    );

    Widget content;
    if (current == 'home') {
      content = HomeView(state: state, plan: plan, go: go);
    } else {
      final kids = <Widget>[
        if (current == 'compose') const ChatIntro(),
        if (current == 'agenda')
          AgendaSwitch(week: week, onChanged: (w) => setState(() => week = w)),
        if (current == 'compose' && state.attachment)
          SourceChip(onRemove: () => setState(() => state.attachment = false)),
        if (current == 'plan')
          PlanView(state: state, plan: plan)
        else
          for (var i = 0; i < s.blocks.length; i++) buildBlock(s.blocks[i], i, ctx),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < s.actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                OButton(
                  label: s.actions[i]['label'] as String,
                  style: s.actions[i]['style'] as String,
                  onTap: () => act(s.actions[i]),
                ),
              ],
            ],
          ),
        ),
      ];
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kids.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            kids[i],
          ],
        ],
      );
    }

    return ColoredBox(
      color: C.cream,
      child: Stack(
        children: [
          Column(
            children: [
              FlowHeader(
                isHome: current == 'home',
                title: s.title,
                subtitle: s.subtitle,
                back: s.back,
                onBack: () => go(s.back!),
                onClose: widget.onClose,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: body,
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
                  child: content,
                ),
              ),
              if (s.nav != null) FlowNav(activeId: s.nav!, current: current, go: go),
            ],
          ),
          if (toast.isNotEmpty) Toast(message: toast, onClose: () => setState(() => toast = '')),
        ],
      ),
    );
  }
}
