/*
 * Copyright (C) 2015 GarageGames LLC
 */

package {
	import flash.desktop.NativeApplication;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.InvokeEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	
	import scratch.ScratchObj;
	
	import ui.parts.DesignTabPart;
	import ui.parts.GlobalTabPart;
	
	import uiwidgets.DialogBox;
	import uiwidgets.Menu;
	
	import util.ProjectIO;
	
public class Designer extends Scratch {
	public static var dapp:Designer; // static reference to the app, used for debugging
	
	protected var lastViewedObject:ScratchObj = null;
	
	protected var globalTabPart:GlobalTabPart;
	public var designTabPart:DesignTabPart;

	protected var displayFPSCounter:Boolean = false;	// Tracks displaying the FPS counter
	
	public var projectPath:String = '';				// The OS path to the save file, including name
	protected var postExportAction:Function = null; // Function to call following a successful export, normally to quit the app
	
	private var debugTextBox:TextField = null;

	public function Designer() {
		dapp = this;
	}
	
	override protected function initialize():void {
		super.initialize();
		
		// Designer specific events
		stage.nativeWindow.addEventListener(Event.CLOSING, closeApplication, false, 0, true);

		// Add a debug text box
		//debugTextBox = new TextField();
		//debugTextBox.autoSize = TextFieldAutoSize.LEFT;
		//debugTextBox.selectable = false;
		//debugTextBox.background = false;
		//debugTextBox.defaultTextFormat = new TextFormat(CSS.font, 12, 0);
		//debugTextBox.x = 50;
		//debugTextBox.y = 30;
		//addChild(debugTextBox);
		//debugText('DEBUG TEXT BOX');

		// Listen for OS application events, such as passing in command line parameters
		NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, onAppInvoke);
	}
	
	public function debugText(text:String):void {
		if(debugTextBox != null) {
			debugTextBox.text = text;
		}
	}

	override protected function addFileMenuItems(b:*, m:Menu):void {
		m.addItem('Open', runtime.selectProjectFile);
		m.addItem('Save', exportProjectToFile);
		m.addItem('Save As', menuSaveAs);
		if (canUndoRevert()) {
			m.addLine();
			m.addItem('Undo Revert', undoRevert);
		} else if (canRevert()) {
			m.addLine();
			m.addItem('Revert', revertToOriginalProject);
		}
		
		if (b.lastEvent.shiftKey) {
			m.addLine();
			m.addItem('Save Project Summary', saveSummary);
		}
		if (b.lastEvent.shiftKey && jsEnabled) {
			m.addLine();
			m.addItem('Import experimental extension', function():void {
				function loadJSExtension(dialog:DialogBox):void {
					var url:String = dialog.getField('URL').replace(/^\s+|\s+$/g, '');
					if (url.length == 0) return;
					externalCall('ScratchExtensions.loadExternalJS', null, url);
				}
				var d:DialogBox = new DialogBox(loadJSExtension);
				d.addTitle('Load Javascript Scratch Extension');
				d.addField('URL', 120);
				d.addAcceptCancelButtons('Load');
				d.showOnStage(app.stage);
			});
		}
		
		m.addLine();
		m.addItem('Quit', applicationExit);
	}

	override protected function addEditMenuItems(b:*, m:Menu):void {
		m.addLine();
		m.addItem('Edit block colors', editBlockColors);

		m.addLine();
		m.addItem('Toggle Template Sprites Tab', toggleTemplateSpritesTab);
		m.addItem('Toggle Global Tab', toggleGlobalTab);
		m.addItem('Toggle Access Data By Strings blocks', toggleAccessDataByStrings);
		
		if (b.lastEvent.shiftKey) {
			m.addLine();
			m.addItem('Toggle FPS Counter', toggleFPSCounter);

			m.addItem('Toggle Focus Area blocks', toggleFocusAreaBlocks);
		}
	}

	protected function toggleFPSCounter():void {
		if(displayFPSCounter) {
			displayFPSCounter = false;
			removeFrameRateReadout();
		} else {
			displayFPSCounter = true;
			addFrameRateReadout(10, 29);
		}
	}
	
	protected function toggleFocusAreaBlocks():void {
		if (app.canAddFocusAreaBlocks) {
			app.canAddFocusAreaBlocks = false;
		} else {
			app.canAddFocusAreaBlocks = true;
		}
		
		Scratch.app.translationChanged();
	}
	
	protected function toggleAccessDataByStrings():void {
		if (app.showDataByStringBlocks) {
			app.showDataByStringBlocks = false;
		} else {
			app.showDataByStringBlocks = true;
		}
		
		Scratch.app.translationChanged();
	}
	
	protected function toggleGlobalTab():void {
		tabsPart.toggleGlobalTab();
	}
	
	protected function toggleTemplateSpritesTab():void {
		libraryPart.toggleSpriteTemplateTabs();
	}

	override public function showAboutMenu(b:*):void {
		// Just display a dialog
		DialogBox.notify(
			'DevPro Game Stack v0.8.0',
			'\nCopyright © 2015 GarageGames LLC' +
			'\n\nBased on Scratch from the MIT Media Laboratory' +
			'\nunder the GPL 2 license.', stage);
	}
	
	override protected function saveProjectAndThen(postSaveAction:Function = null):void {
		// Give the user a chance to save their project, if needed, then call postSaveAction.
		function doNothing():void {}
		function cancel():void { d.cancel(); }
		function proceedWithoutSaving():void { d.cancel(); postSaveAction() }
		function save():void {
			d.cancel();
			
			// Set this as exportProjectToFile() is asynchronous and returns here
			// immediately without clearing saveNeeded first.
			postExportAction = postSaveAction;
			
			exportProjectToFile(); // if this succeeds, saveNeeded will become false
		}
		if (postSaveAction == null) postSaveAction = doNothing;
		if (!saveNeeded) {
			postSaveAction();
			return;
		}
		var d:DialogBox = new DialogBox();
		d.addTitle('Save project?');
		d.addButton('Save', save);
		d.addButton('Don\'t save', proceedWithoutSaving);
		d.addButton('Cancel', cancel);
		d.showOnStage(stage);
	}

	override protected function exportProjectToFile(fromJS:Boolean = false):void {
		function squeakSoundsConverted():void {
			// For Game Snap
			function saveZipData(event:Event):void {
				var ext:String = '.stack';
				
				//var newFile:File = event.target as File;
				var tempArray:Array = File(event.target).nativePath.split(File.separator);
				var fileName:String = tempArray.pop(); // Remove last array item, which should be the file name
				if(fileName.lastIndexOf(ext) == -1) {
					fileName += ext;
				}
				
				// Add back the file name
				tempArray.push(fileName);
				
				// Write!
				var fs:FileStream = new FileStream();
				var newFile:File = new File(tempArray.join(File.separator));
				fs.open(newFile, FileMode.WRITE);
				fs.writeBytes(zipData);
				fs.close();
				
				if (!fromJS) setProjectName(fileName);
				
				// Store the project's path
				setProjectPath(event.target.nativePath);

				clearSaveNeeded();
				
				if(postExportAction != null) {
					postExportAction();
					postExportAction = null;
				}
			}
			
			// Make sure everything is saved
			scriptsPane.saveScripts(false);
			
			// Make the default name
			var projName:String = projectName();
			projName = projName.replace(/^\s+|\s+$/g, ''); // Remove whitespace
			//var defaultName:String = (projName.length > 0) ? projName + '.sb2' : 'project.sb2';
			var defaultName:String = (projName.length > 0) ? projName + '.stack' : 'project.stack';
			
			// Get the project's binary file
			var zipData:ByteArray = projIO.encodeProjectAsZipFile(stagePane);
			
			// If the project has been previously saved then use the stored path.
			// Otherwise, ask the user for a new path.
			if(hasProjectPath()) {
				// Write out to the existing path
				var fs:FileStream = new FileStream();
				var targetFile:File = new File(getProjectPath());
				fs.open(targetFile, FileMode.WRITE);
				fs.writeBytes(zipData);
				fs.close();
				
				clearSaveNeeded();
				
				if(postExportAction != null) {
					postExportAction();
					postExportAction = null;
				}
				
				// Debugging
				//showDebugDialog("exportProjectToFile", "Save File path: " + getProjectPath());
			} else {
				// Need to ask for a filename and path
				//var file:File = new File();
				//file.addEventListener(Event.COMPLETE, fileSaved);
				//file.addEventListener(Event.CANCEL, fileError);
				//file.addEventListener(flash.events.IOErrorEvent.IO_ERROR, fileError);
				//file.save(zipData, fixFileName(defaultName));
				var file:File = File.applicationStorageDirectory;
				file = file.resolvePath(fixFileName(defaultName));
				file.addEventListener(Event.SELECT, saveZipData);
				file.browseForSave("Save As");
			}
		}
		function fileSaved(e:Event):void {
			if (!fromJS) setProjectName(e.target.name);
			
			// Store the project's path
			setProjectPath(e.target.nativePath);
			
			clearSaveNeeded();
			
			if(postExportAction != null) {
				postExportAction();
				postExportAction = null;
			}
			
			// Debugging
			//showDebugDialog("exportProjectToFile", "Save As File path: " + e.target.nativePath);
		}
		function fileError(e:Event):void {
			postExportAction = null;
		}
		
		if (loadInProgress) {
			postExportAction = null;
			return;
		}
		
		var projIO:ProjectIO = new ProjectIO(this);
		projIO.convertSqueakSounds(stagePane, squeakSoundsConverted);
	}
	
	protected function menuSaveAs():void {
		// Save any previous file path
		var oldPath:String = getProjectPath();
		
		// Clear the current path to force the save dialog
		clearProjectPath();
		
		// Attempt to export the project
		exportProjectToFile();
		
		// If there is still no path then the user has canceled the operation.
		// Restore the old path.
		if(!hasProjectPath()) {
			setProjectPath(oldPath);
		}
	}
	
	// Display a dialog with a title and body text.  Use \n to separate lines
	// in the body.
	private function showDebugDialog(title:String, body:String):void {
		DialogBox.notify(
			title,
			body,
			stage);
	}
	
	// Override the Scratch.as version
	override protected function addParts():void {
		super.addParts();
		
		//globalTabPart = new GlobalTabPart(this);
		designTabPart = new DesignTabPart(this);
		
	}
	
	// Copied from Scratch.as
	override public function selectSprite(obj:ScratchObj):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		viewedObject = obj;
		libraryPart.refresh();
		tabsPart.refresh();
		if (isShowing(imagesPart)) {
			imagesPart.refresh();
		}
		if (isShowing(soundsPart)) {
			soundsPart.currentIndex = 0;
			soundsPart.refresh();
		}
		if (isShowing(scriptsPart)) {
			if(scriptsPart.isViewingGlobalTab()) {
				// Force a change to the Scripts tabs when switching sprites
				setTab("scripts");
			}
			else {
				scriptsPart.updatePalette();
				scriptsPane.viewScriptsFor(obj);
				scriptsPart.updateSpriteWatermark();
			}
		}
	}

	// Copied from Scratch.as
	override public function setTab(tabName:String):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		hide(scriptsPart);
		hide(imagesPart);
		hide(soundsPart);
		//hide(globalTabPart);
		if (!editMode) return;
		if (tabName == 'images') {
			show(imagesPart);
			imagesPart.refresh();
		} else if (tabName == 'sounds') {
			soundsPart.refresh();
			show(soundsPart);
		} else if (tabName == 'design') {
			//designTabPart.refresh();
			show(designTabPart);
		} else if (tabName == 'global') {
			scriptsPart.setGlobalTab(true);
			
			if(viewedObject != stagePane.globalObjSprite()) {
				lastViewedObject = viewedObject;
			}
			
			viewedObject = stagePane.globalObjSprite();// Try and present only the global sprite
			libraryPart.refresh();
			tabsPart.refresh();
			
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(viewedObject);
			//scriptsPart.updateSpriteWatermark();
			scriptsPart.clearSpriteWatermark();
			show(scriptsPart);
		} else if (tabName && (tabName.length > 0)) {
			tabName = 'scripts';
			scriptsPart.setGlobalTab(false);
			
			// Do we need to switchto the last viewed object?
			if(viewedObject == stagePane.globalObjSprite() && lastViewedObject != null) {
				viewedObject = lastViewedObject;
				lastViewedObject = null;
				libraryPart.refresh();
				tabsPart.refresh();
			}
			
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(viewedObject);
			scriptsPart.updateSpriteWatermark();
			show(scriptsPart);
		}
		show(tabsPart);
		show(stagePart); // put stage in front
		tabsPart.selectTab(tabName);
		lastTab = tabName;
		if (saveNeeded) setSaveNeeded(true); // save project when switching tabs, if needed (but NOT while loading!)
	}

	
	override protected function updateContentArea(contentX:int, contentY:int, contentW:int, contentH:int, fullH:int):void {
		super.updateContentArea(contentX, contentY, contentW, contentH, fullH);
		designTabPart.x = contentX;
		designTabPart.y = contentY;
		designTabPart.setWidthHeight(contentW, contentH);
	}

	// Get the project's native file path (including file name)
	public function getProjectPath():String {
		return projectPath;
	}
	
	// Set the project's native file path (should include file name and extension)
	public function setProjectPath(path:String):void {
		projectPath = path;
	}
	
	// Clear the project's native file path
	public function clearProjectPath():void {
		projectPath = '';
	}
	
	// Has a file path been defined for this project?
	public function hasProjectPath():Boolean {
		if(projectPath.length != 0)
		{
			return true;
		}
		
		return false;
	}
	
	// Attempt to exit the application
	protected function applicationExit():void {
		//var exitEvent:Event = new Event(Event.EXITING, false, true);
		//NativeApplication.nativeApplication.dispatchEvent(exitEvent);
		var closingEvent:Event = new Event(Event.CLOSING, false, true);
		stage.nativeWindow.dispatchEvent(closingEvent);
	}
	
	// Respond to the window closing event
	protected function closeApplication(e:Event):void {
		// Stop the window from closing
		e.preventDefault();
		
		// Do we need to save?
		if(saveNeeded) {
			// Attempt to save
			saveProjectAndThen(forceApplicationExit);
		} else {
			// Don't need to save
			forceApplicationExit();
		}
	}
	
	protected function forceApplicationExit():void {
		NativeApplication.nativeApplication.exit();
	}

	private var invokedFile:FileReference;
	
	// Respond to the native application invoke event.  This passes in command line
	// arguments and the current application path.
	private function onAppInvoke( event:InvokeEvent ):void {
		var fileName:String, data:ByteArray;
		var filePath:String;
		function projectLoadComplete(fevent:Event):void {
			// File has been loaded and we have the data
			data = invokedFile.data;
			filePath = fevent.target.nativePath;
			runtime.installProjectFromFile(fileName, filePath, data);
			invokedFile = null;
		}
		function projectLoadError(event:Event):void {
			// Ran into an error
			DialogBox.notify(
				'Open Project Error',
				'Could not open project file:' +
				'\n'+event.target.nativePath, stage);
			
			invokedFile = null;
		}
		
		// The first passed in command line argument is an optional project to load
		if(event.arguments.length > 0) {
			var dir:File = event.currentDirectory;
			invokedFile = dir.resolvePath(event.arguments[0]);
			var extension:String = invokedFile.extension;
			
			if(extension == 'stack' || extension == 'snap' || extension == 'sb2' || extension == 'sb') {
				fileName = invokedFile.name;
				
				// We need to load in the file to retrieve its data
				invokedFile.addEventListener(Event.COMPLETE, projectLoadComplete);
				invokedFile.addEventListener(IOErrorEvent.IO_ERROR, projectLoadError);
				invokedFile.load();
			}
		}
	}
}}
