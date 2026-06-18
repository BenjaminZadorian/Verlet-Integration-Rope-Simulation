extends Node

@onready var scrollContainer = $ScrollContainer/GridContainer
@onready var pinnedContainer = $PinnedFiles/PinnedContainer
@onready var filePath = $FilePath

var path : String = ""
var filePresent : bool = false
var limitedFileTypes : Array = []

signal done(path : String)

func _ready() -> void:
	# Set the base filepath to the Documents folder
	path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	SetLayout()
	# Access an array of default pinned documents in the autoload script
	for pinned in Globals.pinnedDirs:
		AddPinnedButton(pinned)

func AddPinnedButton(pinnedArray : Array):
	var pinnedButton = Button.new()
	pinnedButton.text = pinnedArray[0]
	pinnedContainer.add_child(pinnedButton)
	pinnedButton.pressed.connect(ToDir.bind(pinnedArray[1]))

func ToDir(newPath : String):
	path = newPath
	SetLayout()

func openFolder(folderName : String):
	if filePresent:
		path = path.get_base_dir()
	path = path + "/" + folderName
	SetLayout()
	
func openFile(fileName : String):
	if filePresent:
		path = path.get_base_dir()
	path = path + "/" + fileName
	filePath.text = path
	filePresent = true

func SetLayout():
	filePath.text = path
	
	# Destroy all old directories then create the new ones
	for fileIterator in scrollContainer.get_children():
		fileIterator.queue_free()
	
	var directory = DirAccess.open(path)
	directory.list_dir_begin()
	var fileName = directory.get_next()
	
	# If file name is empty, you are at the end of the current directory
	while fileName != "":
		var fileButton = Button.new()
		fileButton.text = fileName
		scrollContainer.add_child(fileButton)
		
		if directory.current_is_dir():
			fileButton.pressed.connect(openFolder.bind(fileName))
			
		else:
			fileButton.pressed.connect(openFile.bind(fileName))
			# If the file has a file type that is limited, destroy it
			if limitedFileTypes.size() > 0:
				if !fileName.get_extension() in limitedFileTypes:
					fileButton.queue_free()
			
		fileName = directory.get_next()

func _on_up_directory_pressed() -> void:
	if filePresent : path = path.get_base_dir()
	path = path.get_base_dir()
	SetLayout()

func _on_file_path_text_submitted(new_text: String) -> void:
	if new_text.is_absolute_path():
		path = new_text
		SetLayout()
	else:
		filePath.clear()

func _on_open_file_pressed() -> void:
	emit_signal("done", filePath.text)
	queue_free()

func _on_cancel_pressed() -> void:
	queue_free()

func _on_pin_pressed() -> void:
	var newPath = path
	if filePresent : newPath.get_base_dir()
	var name = newPath.get_file()
	Globals.pinnedDirs.append([name, newPath])
	AddPinnedButton([name, newPath])

func _on_cancel_folder_pressed() -> void:
	$AddFolder.hide()

func _on_create_folder_pressed() -> void:
	$AddFolder.hide()
	if filePresent : path.get_base_dir()
	var dir = DirAccess.open(path)
	dir.make_dir_absolute(path + "/" + $AddFolder/NewName.text)
	SetLayout()

func _on_new_folder_pressed() -> void:
	$AddFolder.show()
