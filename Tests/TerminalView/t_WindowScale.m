/* t_WindowScale.m - TerminalView aligns its cells to the device pixels of
 * its own window's scale factor, which with monitors of different scales
 * need not be the main screen's.
 *
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */

#import <Foundation/Foundation.h>
#import "Testing.h"
#include <math.h>

/* Included in-process to read the cell metrics and the grid size. */
#include "../../TerminalView.m"

/* Stands in for a window on a monitor of another scale. */
@interface ScaledWindow : NSWindow
{
@public
  CGFloat scale;
}
@end

@implementation ScaledWindow
- (CGFloat)userSpaceScaleFactor
{
  return scale;
}
@end

@interface TerminalView (WindowScaleTestAccess)
- (int)test_columns;
- (int)test_drawAll;
- (NSSize)test_border;
@end

@implementation TerminalView (WindowScaleTestAccess)
- (int)test_columns
{
  return screen_width;
}
- (int)test_drawAll
{
  return draw_all;
}
- (NSSize)test_border
{
  return NSMakeSize(border_x, border_y);
}
@end

static BOOL onPixels(CGFloat points, CGFloat scale)
{
  CGFloat px = points * scale;

  return fabs(px - rint(px)) < 0.001;
}

int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  Defaults *prefs;
  TerminalView *view;
  ScaledWindow *win;
  NSSize cell, border;
  CGFloat mainScale, other;
  int columns;

  [NSApplication sharedApplication];

  mainScale = [Defaults deviceScaleFactor];
  /* A factor the main screen does not have, and one where cells of the
     main screen's factor would not land on whole pixels. */
  other = fabs(mainScale - 1.0) < 0.001 ? 1.25 : 1.0;

  prefs = [[Defaults alloc] initEmpty];
  view = [[TerminalView alloc] initWithPreferences:prefs];
  [view setFont:[NSFont userFixedPitchFontOfSize:12]];
  [view setBorderX:4 Y:2];

  /* Set before -init, which already lays the window out at its factor. */
  win = [ScaledWindow alloc];
  win->scale = other;
  win = [win initWithContentRect:NSMakeRect(0, 0, 600, 400)
                       styleMask:NSBorderlessWindowMask
                         backing:NSBackingStoreBuffered
                           defer:YES];
  [[win contentView] addSubview:view];
  [view setFrame:NSMakeRect(0, 0, 600, 400)];

  cell = [view characterCellSize];
  border = [view test_border];
  PASS(onPixels(cell.width, other) && onPixels(cell.height, other),
       "cells are whole device pixels of the window's own factor");
  PASS(onPixels(border.width, other) && onPixels(border.height, other),
       "the border is whole device pixels of the window's own factor");

  /* The window switches to the main screen's factor: until the view is
     realigned, a frame change must not refit the grid with the old cells. */
  columns = [view test_columns];
  win->scale = mainScale;
  [view setFrameSize:NSMakeSize(600 * other / mainScale, 400)];
  PASS([view test_columns] == columns,
       "a frame change while the window's factor is new keeps the grid");

  [view alignToWindowScale];
  cell = [view characterCellSize];
  PASS(onPixels(cell.width, mainScale) && onPixels(cell.height, mainScale),
       "after realigning, cells are whole device pixels of the new factor");
  PASS([view test_drawAll] == 2,
       "realigning redraws every cell, the backing store being new");

  /* The window's content view holds the view too; it must be gone before
     the preferences it reads from are. */
  [view removeFromSuperview];
  RELEASE(view);
  RELEASE(win);
  RELEASE(prefs);
  [arp release];
  return 0;
}
