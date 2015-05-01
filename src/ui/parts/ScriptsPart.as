/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// ScriptsPart.as
// John Maloney, November 2011
//
// This part holds the palette and scripts pane for the current sprite (or stage).

package ui.parts {
	import flash.display.Bitmap;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.getTimer;
	
	import scratch.ScratchObj;
	import scratch.ScratchSprite;
	
	import ui.BlockPalette;
	import ui.PaletteSelector;
	
	import uiwidgets.IndicatorLight;
	import uiwidgets.ScriptsPane;
	import uiwidgets.ScrollFrame;
	import uiwidgets.ZoomWidget;

public class ScriptsPart extends UIPart {

	private var shape:Shape;
	private var selector:PaletteSelector;
	private var spriteWatermark:Bitmap;
	private var paletteFrame:ScrollFrame;
	private var scriptsFrame:ScrollFrame;
	private var zoomWidget:ZoomWidget;

	private const readoutLabelFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);
	private const readoutFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor);

	private var xyDisplay:Sprite;
	private var xLabel:TextField;
	private var yLabel:TextField;
	private var xReadout:TextField;
	private var yReadout:TextField;
	private var lastX:int = -10000000; // impossible value to force initial update
	private var lastY:int = -10000000; // impossible value to force initial update

	// For Game Snap
	private var showSpriteInfo:Boolean;
	private var showGlobalSpriteLabel:Boolean;	// Show a label in the Scripts area so we know we're looking at Globals
	private var globalDisplay:Sprite;
	private var globalLabel:TextField;
	private var globalTab:Boolean;
	
	public function ScriptsPart(app:Scratch) {
		this.app = app;

		addChild(shape = new Shape());
		addChild(spriteWatermark = new Bitmap());
		addXYDisplay();
		addChild(selector = new PaletteSelector(app));

		// For Game Snap
		showSpriteInfo = true;
		globalTab = false;
		addGlobalSpriteDisplay();
		
		var palette:BlockPalette = new BlockPalette();
		palette.color = CSS.tabColor;
		paletteFrame = new ScrollFrame();
		paletteFrame.allowHorizontalScrollbar = false;
		paletteFrame.setContents(palette);
		addChild(paletteFrame);

		var scriptsPane:ScriptsPane = new ScriptsPane(app);
		scriptsFrame = new ScrollFrame();
		scriptsFrame.setContents(scriptsPane);
		addChild(scriptsFrame);

		app.palette = palette;
		app.scriptsPane = scriptsPane;

		addChild(zoomWidget = new ZoomWidget(scriptsPane));
	}

	// Game Snap: Set the Global tab as active
	public function setGlobalTab(inGlobalTab:Boolean):void {
		globalTab = inGlobalTab;
		if(globalTab == true) {
			showSpriteInfo = false;
		}
		else {
			showSpriteInfo = true;
		}
	}
	
	// Game Snap: Is the Global tab being viewed?
	public function isViewingGlobalTab():Boolean {
		return globalTab;
	}
	
	public function resetCategory():void { selector.select(Specs.motionCategory) }

	public function updatePalette():void {
		selector.updateTranslation();
		selector.select(selector.selectedCategory);
	}

	public function updateSpriteWatermark():void {
		var target:ScratchObj = app.viewedObj();
		if (target && !target.isStage && showSpriteInfo == true) { // Added the showSpriteInfo check for Game Snap
			spriteWatermark.bitmapData = target.currentCostume().thumbnail(40, 40, false);
		} else {
			spriteWatermark.bitmapData = null;
		}
	}

	// For Game Snap
	public function clearSpriteWatermark():void {
		spriteWatermark.bitmapData = null;
	}
	
	public function step():void {
		// Update the mouse readouts. Do nothing if they are up-to-date (to minimize CPU load).
		var target:ScratchObj = app.viewedObj();
		// Designer: The target object could be null when we first start with a project template rather than an empty scene
		if(target == null) {
			return;
		}
		if (target.isStage) {
			if (xyDisplay.visible) xyDisplay.visible = false;
			if (globalDisplay.visible) globalDisplay.visible = false;	// For Game Snap
		} else {
			// Added this section for Game Snap
			if(showSpriteInfo == true)
			{
				// This is the original line of code rather than the IF block
				if (!xyDisplay.visible) xyDisplay.visible = true;
				if (globalDisplay.visible) globalDisplay.visible = false;	// For Game Snap
			}
			else
			{
				if (xyDisplay.visible) xyDisplay.visible = false;
				if (!globalDisplay.visible) globalDisplay.visible = true;	// For Game Snap
			}

			var spr:ScratchSprite = target as ScratchSprite;
			if (!spr) return;
			if (spr.scratchX != lastX) {
				lastX = spr.scratchX;
				xReadout.text = String(lastX);
			}
			if (spr.scratchY != lastY) {
				lastY = spr.scratchY;
				yReadout.text = String(lastY);
			}
		}
		updateExtensionIndicators();
	}

	private var lastUpdateTime:uint;

	private function updateExtensionIndicators():void {
		if ((getTimer() - lastUpdateTime) < 500) return;
		for (var i:int = 0; i < app.palette.numChildren; i++) {
			var indicator:IndicatorLight = app.palette.getChildAt(i) as IndicatorLight;
			if (indicator) app.extensionManager.updateIndicator(indicator, indicator.target);
		}		
		lastUpdateTime = getTimer();
	}

	public function setWidthHeight(w:int, h:int):void {
		this.w = w;
		this.h = h;
		fixlayout();
		redraw();
	}

	private function fixlayout():void {
		selector.x = 1;
		selector.y = 5;
		paletteFrame.x = selector.x;
		paletteFrame.y = selector.y + selector.height + 2;
		paletteFrame.setWidthHeight(selector.width + 1, h - paletteFrame.y - 2); // 5
		scriptsFrame.x = selector.x + selector.width + 2;
		scriptsFrame.y = selector.y + 1;
		scriptsFrame.setWidthHeight(w - scriptsFrame.x - 5, h - scriptsFrame.y - 5);
		spriteWatermark.x = w - 60;
		spriteWatermark.y = scriptsFrame.y + 10;
		xyDisplay.x = spriteWatermark.x + 1;
		xyDisplay.y = spriteWatermark.y + 43;
		zoomWidget.x = w - zoomWidget.width - 15;
		zoomWidget.y = h - zoomWidget.height - 15;
		
		// For Game Snap
		globalDisplay.x = w - 90;
		globalDisplay.y = scriptsFrame.y + 10;
	}

	private function redraw():void {
		var paletteW:int = paletteFrame.visibleW();
		var paletteH:int = paletteFrame.visibleH();
		var scriptsW:int = scriptsFrame.visibleW();
		var scriptsH:int = scriptsFrame.visibleH();

		var g:Graphics = shape.graphics;
		g.clear();
		g.lineStyle(1, CSS.borderColor, 1, true);
		g.beginFill(CSS.tabColor);
		g.drawRect(0, 0, w, h);
		g.endFill();

		var lineY:int = selector.y + selector.height;
		var darkerBorder:int = CSS.borderColor - 0x141414;
		var lighterBorder:int = 0xF2F2F2;
		g.lineStyle(1, darkerBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY, paletteW - 20);
		g.lineStyle(1, lighterBorder, 1, true);
		hLine(g, paletteFrame.x + 8, lineY + 1, paletteW - 20);

		g.lineStyle(1, darkerBorder, 1, true);
		g.drawRect(scriptsFrame.x - 1, scriptsFrame.y - 1, scriptsW + 1, scriptsH + 1);
	}

	private function hLine(g:Graphics, x:int, y:int, w:int):void {
		g.moveTo(x, y);
		g.lineTo(x + w, y);
	}

	private function addXYDisplay():void {
		xyDisplay = new Sprite();
		xyDisplay.addChild(xLabel = makeLabel('x:', readoutLabelFormat, 0, 0));
		xyDisplay.addChild(xReadout = makeLabel('-888', readoutFormat, 15, 0));
		xyDisplay.addChild(yLabel = makeLabel('y:', readoutLabelFormat, 0, 13));
		xyDisplay.addChild(yReadout = makeLabel('-888', readoutFormat, 15, 13));
		addChild(xyDisplay);
	}

	// For Game Snap
	private function addGlobalSpriteDisplay():void {
		globalDisplay = new Sprite();
		globalDisplay.addChild(globalLabel = makeLabel('Global Sprite', readoutLabelFormat, 0, 0));
		addChild(globalDisplay);
	}
}}
