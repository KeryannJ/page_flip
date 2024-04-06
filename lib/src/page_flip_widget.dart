import 'dart:async';

import 'package:flutter/material.dart';

import '../page_flip.dart';

class PageFlipWidget extends StatefulWidget {
  const PageFlipWidget(
      {Key? key,
      this.duration = const Duration(milliseconds: 450),
      this.cutoffForward = 0.8,
      this.cutoffPrevious = 0.1,
      this.backgroundColor = Colors.white,
      required this.children,
      this.initialIndex = 0,
      this.lastPage,
      this.isRightSwipe = false,
      this.onPageChanged,
      this.onPrevPage,
      this.onNextPage,
      this.onJump,
      this.onLastPageReached})
      : assert(initialIndex < children.length,
            'initialIndex cannot be greater than children length'),
        super(key: key);

  final Color backgroundColor;
  final List<Widget> children;
  final Duration duration;
  final int initialIndex;
  final Widget? lastPage;
  final double cutoffForward;
  final double cutoffPrevious;
  final bool isRightSwipe;
  final Function(int newIndex)? onPageChanged;
  final Function(int newIndex)? onPrevPage;
  final Function(int newIndex)? onNextPage;
  final Function(int jumpSize, int newIndex)? onJump;
  final Function()? onLastPageReached;

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

class PageFlipWidgetState extends State<PageFlipWidget>
    with TickerProviderStateMixin {
  int pageNumber = 0;
  List<Widget> pages = [];
  final List<AnimationController> _controllers = [];
  bool? _isForward;

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    imageData = {};
    currentPage = ValueNotifier(-1);
    currentWidget = ValueNotifier(Container());
    currentPageIndex = ValueNotifier(0);
    _setUp();
  }

  void _setUp({bool isRefresh = false}) {
    _controllers.clear();
    pages.clear();
    if (widget.lastPage != null) {
      widget.children.add(widget.lastPage!);
    }
    for (var i = 0; i < widget.children.length; i++) {
      final controller = AnimationController(
        value: 1,
        duration: widget.duration,
        vsync: this,
      );
      _controllers.add(controller);
      final child = PageFlipBuilder(
        amount: controller,
        backgroundColor: widget.backgroundColor,
        isRightSwipe: widget.isRightSwipe,
        pageIndex: i,
        key: Key('item$i'),
        child: widget.children[i],
      );
      pages.add(child);
    }
    pages = pages.reversed.toList();
    if (isRefresh) {
      goToPage(pageNumber);
    } else {
      pageNumber = widget.initialIndex;
      goToPage(pageNumber);
      lastPageLoad = pages.length < 3 ? 0 : 3;
    }
    if (widget.initialIndex != 0) {
      currentPage = ValueNotifier(widget.initialIndex);
      currentWidget = ValueNotifier(pages[pageNumber]);
      currentPageIndex = ValueNotifier(widget.initialIndex);
    }
  }

  bool get _isLastPage => (pages.length - 1) == pageNumber;

  int lastPageLoad = 0;

  bool get _isFirstPage => pageNumber == 0;

  void _turnPage(DragUpdateDetails details, BoxConstraints dimens) {
    // if ((_isLastPage) || !isFlipForward.value) return;
    currentPage.value = pageNumber;
    currentWidget.value = Container();
    final ratio = details.delta.dx / dimens.maxWidth;
    if (_isForward == null) {
      if (widget.isRightSwipe
          ? details.delta.dx < 0.0
          : details.delta.dx > 0.0) {
        _isForward = false;
      } else if (widget.isRightSwipe
          ? details.delta.dx > 0.2
          : details.delta.dx < -0.2) {
        _isForward = true;
      } else {
        _isForward = null;
      }
    }

    if (_isForward == true || pageNumber == 0) {
      final pageLength = pages.length;
      final pageSize = widget.lastPage != null ? pageLength : pageLength - 1;
      if (pageNumber != pageSize && !_isLastPage) {
        widget.isRightSwipe
            ? _controllers[pageNumber].value -= ratio
            : _controllers[pageNumber].value += ratio;
      }
    }
  }

  Future _onDragFinish() async {
    if (_isForward != null) {
      if (_isForward == true) {
        if (!_isLastPage &&
            _controllers[pageNumber].value <= (widget.cutoffForward + 0.15)) {
          await nextPage();
        } else {
          if (!_isLastPage) {
            await _controllers[pageNumber].forward();
          }
        }
      } else {
        if (!_isFirstPage &&
            _controllers[pageNumber - 1].value >= widget.cutoffPrevious) {
          await previousPage();
        } else {
          if (_isFirstPage) {
            await _controllers[pageNumber].forward();
          } else {
            await _controllers[pageNumber - 1].reverse();
            if (!_isFirstPage) {
              await previousPage();
            }
          }
        }
      }
    }
    _isForward = null;
    currentPage.value = -1;
  }

  Future nextPage() async {
    await _controllers[pageNumber].reverse();
    if (mounted) {
      setState(() {
        pageNumber++;
      });
    }

    if (widget.onPageChanged != null) {
      widget.onPageChanged!(pageNumber);
    }

    if (widget.onNextPage != null) {
      widget.onNextPage!(pageNumber);
    }

    if (widget.onLastPageReached != null) {
      widget.onLastPageReached!;
    }
    currentPageIndex.value = pageNumber;
    currentWidget.value = pages[pageNumber];
  }

  Future previousPage() async {
    await _controllers[pageNumber - 1].forward();
    if (mounted) {
      setState(() {
        pageNumber--;
      });
    }
    if (widget.onPageChanged != null) {
      widget.onPageChanged!(pageNumber);
    }
    if (widget.onPrevPage != null) {
      widget.onPrevPage!(pageNumber);
    }
    currentPageIndex.value = pageNumber;
    currentWidget.value = pages[pageNumber];
    imageData[pageNumber] = null;
  }

  void fixAnimationDirection(bool aForward) {
    for (var i = 0; i < _controllers.length; i++) {
      if (i < pageNumber) {
        _controllers[i].value = 0.0;
      } else if (i > pageNumber) {
        _controllers[i].value = 1.0;
      } else {
        _controllers[i].value = aForward ? 1.0 : 0.0;
      }
    }
  }

  Future goToPage(int index) async {
    if (!mounted) return;

    final isForward = index > pageNumber;
    fixAnimationDirection(isForward);
    final targetValue = isForward ? 0.0 : 1.0;

    if (isForward) {
      for (var i = pageNumber; i < index; i++) {
        await _controllers[i].animateTo(targetValue,
            duration: const Duration(milliseconds: 200));
      }
    } else {
      for (var i = pageNumber; i > index; i--) {
        await _controllers[i].animateTo(targetValue,
            duration: const Duration(milliseconds: 200));
      }
    }

    setState(() {
      pageNumber = index;
    });

    if (_isLastPage && widget.onLastPageReached != null) {
      widget.onLastPageReached!();
    }
    if (widget.onPageChanged != null) {
      widget.onPageChanged!(pageNumber);
    }
    if (widget.onJump != null) {
      widget.onJump!(pageNumber - currentPageIndex.value, pageNumber);
    }

    currentPageIndex.value = pageNumber;
    currentWidget.value = pages[pageNumber];
    currentPage.value = pageNumber;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimens) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {},
        onTapUp: (details) {},
        onPanDown: (details) {},
        onPanEnd: (details) {},
        onTapCancel: () {},
        onHorizontalDragCancel: () => _isForward = null,
        onHorizontalDragUpdate: (details) => _turnPage(details, dimens),
        onHorizontalDragEnd: (details) => _onDragFinish(),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.lastPage != null) ...[
              widget.lastPage!,
            ],
            if (pages.isNotEmpty) ...pages else ...[const SizedBox.shrink()],
          ],
        ),
      ),
    );
  }
}
