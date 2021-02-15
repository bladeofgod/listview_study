



import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as originRendering;
import 'package:flutter_list_view_study/custom/global_constant.dart';

import 'custom_sliver_adaptor_widget.dart';
import 'custom_sliver_box_adaptor.dart';

class CustomSliverMultiBoxAdaptorElement extends RenderObjectElement implements originRendering.RenderSliverBoxChildManager{
  /// Creates an element that lazily builds children for the given widget.
  CustomSliverMultiBoxAdaptorElement(CustomSliverMultiBoxAdaptorWidget widget) : super(widget);

  @override
  CustomSliverMultiBoxAdaptorWidget get widget => super.widget as CustomSliverMultiBoxAdaptorWidget;

  @override
  CustomRenderSliverMultiBoxAdaptor get renderObject => super.renderObject as CustomRenderSliverMultiBoxAdaptor;

  @override
  void update(covariant CustomSliverMultiBoxAdaptorWidget newWidget) {
    final CustomSliverMultiBoxAdaptorWidget oldWidget = widget;
    super.update(newWidget);
    final SliverChildDelegate newDelegate = newWidget.delegate;
    final SliverChildDelegate oldDelegate = oldWidget.delegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType || newDelegate.shouldRebuild(oldDelegate)))
      performRebuild();
  }

  final SplayTreeMap<int, Element> _childElements = SplayTreeMap<int, Element>();
  RenderBox _currentBeforeChild;
  ///标记废弃的child element
  /// * 总是标记靠近边界的值
  //final List<int> removeMarkers = [];

  @override
  void performRebuild() {
    super.performRebuild();
    _currentBeforeChild = null;
    assert(_currentlyUpdatingChildIndex == null);
    debugPrint('performRebuild');
    try {
      final SplayTreeMap<int, Element> newChildren = SplayTreeMap<int, Element>();
      final Map<int, double> indexToLayoutOffset = HashMap<int, double>();

      void processElement(int index) {
        _currentlyUpdatingChildIndex = index;
        if (_childElements[index] != null && _childElements[index] != newChildren[index]) {
          // This index has an old child that isn't used anywhere and should be deactivated.
          _childElements[index] = updateChild(_childElements[index], null, index);
        }
        final Element newChild = updateChild(newChildren[index], _build(index), index);
        if (newChild != null) {
          _childElements[index] = newChild;
          final SliverMultiBoxAdaptorParentData parentData = newChild.renderObject.parentData as SliverMultiBoxAdaptorParentData;
          if (index == 0) {
            parentData.layoutOffset = 0.0;
          } else if (indexToLayoutOffset.containsKey(index)) {
            parentData.layoutOffset = indexToLayoutOffset[index];
          }
          if (!parentData.keptAlive)
            _currentBeforeChild = newChild.renderObject as RenderBox;
        } else {
          _childElements.remove(index);
        }
      }
      for (final int index in _childElements.keys.toList()) {
        final Key key = _childElements[index].widget.key;
        final int newIndex = key == null ? null : widget.delegate.findIndexByKey(key);

        //这里的childParentData.layoutOffset 只有三个值，应该是根据屏幕来定的（与child个数无关或缓存）
        final SliverMultiBoxAdaptorParentData childParentData =
        _childElements[index].renderObject?.parentData as SliverMultiBoxAdaptorParentData;
        //debugPrint('layout offset : ${childParentData.layoutOffset}');

        if (childParentData != null && childParentData.layoutOffset != null)
          indexToLayoutOffset[index] = childParentData.layoutOffset;

        if (newIndex != null && newIndex != index) {
          // The layout offset of the child being moved is no longer accurate.
          if (childParentData != null)
            childParentData.layoutOffset = null;

          newChildren[newIndex] = _childElements[index];
          // We need to make sure the original index gets processed.
          newChildren.putIfAbsent(index, () => null);
          // We do not want the remapped child to get deactivated during processElement.
          _childElements.remove(index);
        } else {

          newChildren.putIfAbsent(index, () => _childElements[index]);
        }
      }

      renderObject.debugChildIntegrityEnabled = false; // Moving children will temporary violate the integrity.
      newChildren.keys.forEach(processElement);
      if (_didUnderflow) {
        final int lastKey = _childElements.lastKey() ?? -1;
        final int rightBoundary = lastKey + 1;
        newChildren[rightBoundary] = _childElements[rightBoundary];
        processElement(rightBoundary);
      }
    } finally {
      _currentlyUpdatingChildIndex = null;
      renderObject.debugChildIntegrityEnabled = true;
    }
  }

  Widget _build(int index) {
    return widget.delegate.build(this, index);
  }

  @override
  void createChild(int index, { @required RenderBox after }) {
    assert(_currentlyUpdatingChildIndex == null);
    debugPrint('len : ${_childElements.length}');
    owner.buildScope(this, () {
      final bool insertFirst = after == null;
      assert(insertFirst || _childElements[index-1] != null);
      _currentBeforeChild = insertFirst ? null : (_childElements[index-1].renderObject as RenderBox);
      Element newChild;
      try {
        _currentlyUpdatingChildIndex = index;
        //如果 在removeChild的时候不删除 _childElements对应的element
        //那么，当执行此处的时候，不按index 从 _childElements 中取element，
        //而是以_childElements.first/last 进行取出复用，这样应该不会触发 inflate（更好的性能）
        //2021.2.1
        //2021.2.12 demo 案例，初始创建3个(2个在屏，1个屏外)
        debugPrint('create child $index');
        debugPrint('child of index is ${_childElements[index]}');
        //final Element temp = removeMarkers.isEmpty ? _childElements[index] : removeMarkers.first;
        //newChild = updateChild(_childElements[index], _build(index), index);
        newChild = updateChild(_childElements[index], _build(index), index);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    });
  }

  @override
  Element updateChild(Element child, Widget newWidget, dynamic newSlot) {
    final SliverMultiBoxAdaptorParentData oldParentData = child?.renderObject?.parentData as SliverMultiBoxAdaptorParentData;
    final Element newChild = super.updateChild(child, newWidget, newSlot);
    final SliverMultiBoxAdaptorParentData newParentData = newChild?.renderObject?.parentData as SliverMultiBoxAdaptorParentData;

    // Preserve the old layoutOffset if the renderObject was swapped out.
    if (oldParentData != newParentData && oldParentData != null && newParentData != null) {
      //测试 demo里 不会进入这个if
      //debugPrint('update child in if');
      newParentData.layoutOffset = oldParentData.layoutOffset;
    }
    return newChild;
  }

  @override
  void forgetChild(Element child) {
    assert(child != null);
    assert(child.slot != null);
    assert(_childElements.containsKey(child.slot));
    _childElements.remove(child.slot);
    super.forgetChild(child);
  }

  /// [_childElements] 类型为<int,Element>,
  /// 对当前显示（包括缓存的）element做记录，
  /// 假设一屏显示5个item，那么[_childElements]总是由5个元素，仅index会 = item的 index
  /// 如果不在[removeChild]中移除 element,配合[createChild]的改造应该会提升性能
  /// 2021.2.1

  @override
  void removeChild(RenderBox child) {
    final int index = renderObject.indexOf(child);
    debugPrint('child element size ${_childElements.length}');
    debugPrint('_child last index ${_childElements.lastKey()}');
    debugPrint(' remove child index  $index');
    assert(_currentlyUpdatingChildIndex == null);
    assert(index >= 0);
    owner.buildScope(this, () {
      assert(_childElements.containsKey(index));
      try {
        _currentlyUpdatingChildIndex = index;
        // origin code
        final Element result = updateChild(_childElements[index], null, index);
        // fixed code
        // final int preLast = GlobalConstant.direction == ScrollDirection.reverse ?
        //     (_childElements.lastKey() + 1).clamp(0, 19)
        //     : (_childElements.firstKey()-1).clamp(0, 19);
        //
        // final Element result = updateChild(_childElements[index], _build(preLast), index);
        //assert(result == null);
      } finally {
        _currentlyUpdatingChildIndex = null;
      }
      debugPrint('remove index  $index');
      //childElements 总是有3个元素。
      _childElements.remove(index);
      debugPrint('child elements : $_childElements');
      //暂定缓存4个
      // if(removeMarkers.length == 4){
      //   removeMarkers.removeAt(0);
      //   removeMarkers.add(index);
      // }else{
      //   removeMarkers.add(index);
      // }
      // debugPrint('remove markers : $removeMarkers');
      //assert(!_childElements.containsKey(index));
    });
  }

  int indexOf(RenderBox child) {
    assert(child != null);
    final SliverMultiBoxAdaptorParentData childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
    assert(childParentData.index = null);
    return childParentData.index;
  }

  static double _extrapolateMaxScrollOffset(
      int firstIndex,
      int lastIndex,
      double leadingScrollOffset,
      double trailingScrollOffset,
      int childCount,
      ) {
    if (lastIndex == childCount - 1)
      return trailingScrollOffset;
    final int reifiedCount = lastIndex - firstIndex + 1;
    final double averageExtent = (trailingScrollOffset - leadingScrollOffset) / reifiedCount;
    final int remainingCount = childCount - lastIndex - 1;
    return trailingScrollOffset + averageExtent * remainingCount;
  }

  @override
  double estimateMaxScrollOffset(
      originRendering.SliverConstraints constraints, {
        int firstIndex,
        int lastIndex,
        double leadingScrollOffset,
        double trailingScrollOffset,
      }) {
    final int childCount = this.childCount;
    if (childCount == null)
      return double.infinity;
    return widget.estimateMaxScrollOffset(
      constraints,
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    ) ?? _extrapolateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
      childCount,
    );
  }

  @override
  int get childCount => widget.delegate.estimatedChildCount;

  @override
  void didStartLayout() {
    assert(debugAssertChildListLocked());
  }

  @override
  void didFinishLayout() {
    assert(debugAssertChildListLocked());
    final int firstIndex = _childElements.firstKey() ?? 0;
    final int lastIndex = _childElements.lastKey() ?? 0;
    widget.delegate.didFinishLayout(firstIndex, lastIndex);
  }

  int _currentlyUpdatingChildIndex;

  @override
  bool debugAssertChildListLocked() {
    assert(_currentlyUpdatingChildIndex == null);
    return true;
  }

  @override
  void didAdoptChild(RenderBox child) {
    assert(_currentlyUpdatingChildIndex != null);
    final SliverMultiBoxAdaptorParentData childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
    childParentData.index = _currentlyUpdatingChildIndex;
  }

  bool _didUnderflow = false;

  @override
  void setDidUnderflow(bool value) {
    _didUnderflow = value;
  }

  @override
  void insertRenderObjectChild(covariant RenderObject child, int slot) {
    assert(slot != null);
    assert(_currentlyUpdatingChildIndex == slot);
    assert(renderObject.debugValidateChild(child));
    renderObject.insert(child as RenderBox, after: _currentBeforeChild);
    assert(() {
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
      assert(slot == childParentData.index);
      return true;
    }());
  }

  @override
  void moveRenderObjectChild(covariant RenderObject child, int oldSlot, int newSlot) {
    assert(newSlot != null);
    assert(_currentlyUpdatingChildIndex == newSlot);
    renderObject.move(child as RenderBox, after: _currentBeforeChild);
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, int slot) {
    assert(_currentlyUpdatingChildIndex != null);
    renderObject.remove(child as RenderBox);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // The toList() is to make a copy so that the underlying list can be modified by
    // the visitor:
    assert(!_childElements.values.any((Element child) => child == null));
    _childElements.values.toList().forEach(visitor);
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _childElements.values.where((Element child) {
      final SliverMultiBoxAdaptorParentData parentData = child.renderObject.parentData as SliverMultiBoxAdaptorParentData;
      double itemExtent;
      switch (renderObject.constraints.axis) {
        case Axis.horizontal:
          itemExtent = child.renderObject.paintBounds.width;
          break;
        case Axis.vertical:
          itemExtent = child.renderObject.paintBounds.height;
          break;
      }

      return parentData.layoutOffset != null &&
          parentData.layoutOffset < renderObject.constraints.scrollOffset + renderObject.constraints.remainingPaintExtent &&
          parentData.layoutOffset + itemExtent > renderObject.constraints.scrollOffset;
    }).forEach(visitor);
  }
}