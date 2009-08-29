// sk, a (very) simple wiki. Copyright 2006, 2008, 2009, Daniel J. Parks.

// 'findPos' and 'Point' borrowed from Tony Chang's webnote project - http://www.aypwip.org/webnote
function findPos(obj) {
  var cur = new Point();
  if (obj.offsetParent) {
    while (obj.offsetParent) {
      cur.x += obj.offsetLeft;
      cur.y += obj.offsetTop;
      obj = obj.offsetParent;
    }
  }
  else if (obj.x) {
    cur.x += obj.x;
    cur.y += obj.y;
  }
  return cur;
}
function Point(x, y) {
  this.x = x ? x : 0;
  this.y = y ? y : 0;
}

// begin my code...
var isIE = document.all ? true : false;
var isResizing, x, y;
var inner, text, handleContainerHeight, handleHeight, handleWidth, innerPos, textPos, minWidth, minHeight;
function initPage() {
  isResizing = false;
  var handle = document.getElementById("resizeHandle");
  handle.onmousedown = mouseDown;
  document.onmousemove = mouseMove;
  document.onmouseup = mouseUp;
  innerPos = findPos(inner = document.getElementById("inner"));
  textPos = findPos(text = document.getElementById("text"));
  minWidth = text.style.width.replace("px", "");
  minHeight = text.style.height.replace("px", "");
  handleHeight = handle.style.height.replace("px", "");
  handleContainerHeight = handleHeight*1 + handle.offsetParent.offsetTop*1;
  handleWidth = handle.style.width.replace("px", "");
}
function mouseDown( e ) {
  isResizing = true;
  return isResizing;
}
function mouseUp( e ) {
  if ( isResizing ) isResizing = false;
  return isResizing;
}
function mouseMove( e ) {
  setXY(e);
  if ( isResizing ) {
    var t = x - innerPos.x;
    inner.style.width = (t < minWidth ? minWidth : t) + "px";
    t = y - innerPos.y - handleHeight*2 + handleContainerHeight;
    inner.style.height = (t < minHeight ? minHeight : t) + "px";
    t = x - textPos.x;
    text.style.width = (t < minWidth ? minWidth : t) + "px";
    t = y - textPos.y - handleHeight*2;
    text.style.height = (t < minHeight ? minHeight : t) + "px";
  }
  return ! isResizing;
}
function setXY( e ) {
  if ( isIE ) {
    x = window.event.x + document.body.scrollLeft;
    y = window.event.y + document.body.scrollTop;
  }
  else {
    x = e.pageX;
    y = e.pageY;
  }
}

