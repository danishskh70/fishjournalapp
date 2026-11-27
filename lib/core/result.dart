import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

Future<bool> runWithResult(
  BuildContext context, {
  required Future<dynamic> Function() action,
  required String working,
  required String okTitle,
  String failTitle = 'Could not save',
  String? failHint,
  List<String> Function(dynamic result)? okLines,
  bool autoClose = true,
  bool retryable = true,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => _ResultScreen(
        action: action,
        working: working,
        okTitle: okTitle,
        failTitle: failTitle,
        failHint: failHint,
        okLines: okLines,
        autoClose: autoClose,
        retryable: retryable,
      ),
    ),
  );
  return result == true;
}

enum _Phase { working, ok, fail }

class _ResultScreen extends StatefulWidget {
  final Future<dynamic> Function() action;
  final String working;
  final String okTitle;
  final String failTitle;
  final String? failHint;
  final List<String> Function(dynamic)? okLines;
  final bool autoClose;
  final bool retryable;

  const _ResultScreen({
    required this.action,
    required this.working,
    required this.okTitle,
    required this.failTitle,
    required this.failHint,
    required this.okLines,
    required this.autoClose,
    required this.retryable,
  });

  @override
  State<_ResultScreen> createState() => _RS();
}

class _RS extends State<_ResultScreen> {
  _Phase phase = _Phase.working;
  String error = '';
  List<String> lines = [];
  Timer? timer;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    run();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> run() async {
    timer?.cancel();

    try {
      final result = await widget.action();
      if (!mounted) return;

      List<String> successLines = [];
      try {
        successLines = widget.okLines?.call(result) ?? [];
      } catch (_) {
        // A display callback must not turn a successful save into a failure.
      }

      if (!mounted) return;
      setState(() {
        lines = successLines;
        error = '';
        phase = _Phase.ok;
      });

      if (widget.autoClose) {
        timer = Timer(const Duration(milliseconds: 1600), () {
          if (mounted) close(true);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        phase = _Phase.fail;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Something went wrong. Please try again.';
        phase = _Phase.fail;
      });
    }
  }

  void close(bool result) {
    if (!mounted || closing) return;
    closing = true;
    timer?.cancel();
    Navigator.pop(context, result);
  }

  void retry() {
    if (phase == _Phase.working || !widget.retryable || closing) return;

    setState(() {
      phase = _Phase.working;
      error = '';
      lines = [];
    });
    run();
  }

  @override
  Widget build(BuildContext c) {
    final working = phase == _Phase.working;
    final ok = phase == _Phase.ok;
    final color = ok ? teal : coral;

    return PopScope(
      canPop: !working,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                if (working)
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 5),
                  )
                else
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: tint(color, 30),
                    child: Icon(
                      ok ? Icons.check_rounded : Icons.close_rounded,
                      size: 56,
                      color: color,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  working
                      ? widget.working
                      : ok
                          ? widget.okTitle
                          : widget.failTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (ok)
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                if (phase == _Phase.fail) ...[
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                  if (widget.failHint != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.failHint!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                const Spacer(),
                if (ok)
                  FilledButton(
                    onPressed: () => close(true),
                    child: const Text('Done'),
                  ),
                if (phase == _Phase.fail) ...[
                  if (widget.retryable)
                    FilledButton(
                      onPressed: retry,
                      child: const Text('Try again'),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => close(false),
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
