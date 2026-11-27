import 'package:flutter/material.dart';

class OnePageScrollPhysics extends PageScrollPhysics {
  const OnePageScrollPhysics({super.parent});

  @override
  OnePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OnePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final dimension = position.viewportDimension;

    if (dimension <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    final page = position.pixels / dimension;

    final targetPage = velocity > tolerance.velocity
        ? page.floor() + 1
        : velocity < -tolerance.velocity
            ? page.ceil() - 1
            : page.round();

    final minPage = (position.minScrollExtent / dimension).round();
    final maxPage = (position.maxScrollExtent / dimension).round();

    final boundedPage = targetPage.clamp(minPage, maxPage);
    final targetPixels = boundedPage * dimension.toDouble();

    if (targetPixels == position.pixels) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
