extends Node2D

# -- Onready --
@onready var tileMapInput : LineEdit = $EditorCamera/UI/HeaderContainer/TilemapInput
@onready var layerLabel : Label = $EditorCamera/UI/HeaderContainer/LayerLabel
@onready var uiNode : Control = $EditorCamera/UI
@onready var tilemapLayerContainer : VBoxContainer = $EditorCamera/UI/TilemapLayerContainer
@onready var fileActionContainer : VBoxContainer = $EditorCamera/UI/FileActionContainer

@onready var tileToSourceDict : Dictionary = {
	[0,1,0,0] : [0,0],
	[1,0,0,1] : [0,1],
	[0,0,1,0] : [0,2],
	[0,0,0,0] : [0,3], # Empty Tile
	[0,0,1,1] : [1,0],
	[0,1,1,1] : [1,1],
	[1,0,1,0] : [1,2],
	[0,0,0,1] : [1,3],
	[1,1,0,1] : [2,0],
	[1,1,1,1] : [2,1],
	[1,0,1,1] : [2,2],
	[0,1,1,0] : [2,3],
	[0,1,0,1] : [3,0],
	[1,1,1,0] : [3,1],
	[1,1,0,0] : [3,2],
	[1,0,0,0] : [3,3]
}

# -- Signals --
signal open(path : String)

const fileExplorer = preload("res://Scenes/FileExplorer.tscn")
var atlasCoord : Vector2i = Vector2i(0,0)
var visualLayerOffset : Vector2i = Vector2i(1,1)

var worldTilemap : TileMapLayer = null
var visualTilemap : TileMapLayer = null
# An array to hold all the different visual layer nodes
var tilemapLayerArray : Array = []

# -- Input Flags --
# editModeLoader stores what layer button is pressed until you stop hovering over the button
# This prevents tiles being placed on accident
var editMode : int = -1
var editModeLoader : int = -1

func _input(event: InputEvent) -> void:
	# 1 = Mouse button left
	if editMode != -1:
		if Input.is_mouse_button_pressed(1):
			PlaceWorldTile()
		if Input.is_mouse_button_pressed(2):
			DeleteWorldTile()

func DeleteWorldTile() -> void:
	var mousePosition : Vector2 = get_global_mouse_position()
	var tilePosition: Vector2i = worldTilemap.local_to_map(mousePosition)
	worldTilemap.erase_cell(tilePosition)
	DeleteVisualTile(tilePosition)

func DeleteVisualTile(tilePosition : Vector2i) -> void:
	for x : int in range(2):
		for y : int in range(2):
			#visualTilemap.erase_cell(tilePosition+Vector2i(x,y))
			tilemapLayerArray[editMode].erase_cell(tilePosition+Vector2i(x,y))
		PlaceVisualTiles(tilePosition)
		
func PlaceWorldTile() -> void:
	# Use global_mouse_position so that the position is independant from the camera, as event.position is based on the viewport
	var mousePosition : Vector2 = get_global_mouse_position()
	# Get the position of the mouse click in relation to the World tilemap
	var tilePosition : Vector2i = worldTilemap.local_to_map(mousePosition)
	# the source ID of the tile -> This can be found in the TileSet section in the editor when hovering over a tile
	var sourceID : int = 0
	worldTilemap.set_cell(tilePosition, sourceID, atlasCoord)

	# Call function to place visual tiles
	PlaceVisualTiles(tilePosition)

	# print("Mouse Click at: ", get_global_mouse_position())
	# print("Tilemap Position: ", self.local_to_map(get_global_mouse_position()))
	# print("Visual Tilemap Position: ", visualTilemap.local_to_map((get_global_mouse_position())))

# Loop through all 4 overlapping tiles (top left, bottom left, top right, bottom right)
func PlaceVisualTiles(tilePosition: Vector2i) -> void:
	for visualLayerOffsetX: int in range(2):
		for visualLayerOffsetY: int in range(2):
			#print("X: ", visualLayerOffsetX)
			#print("Y: ", visualLayerOffsetY)

			# Collect the configuration of all neighbour tiles into an array
			# The configuration is related to the dictionary of tile configurations, to know what one to place
			var tileNeighbours: Array = GetVisualTileConfig(tilePosition + Vector2i(visualLayerOffsetX, visualLayerOffsetY))
			if tileNeighbours != [0,0,0,0]:
				# Get the correct tile to place on the visual layer from the config
				var tilePlacement : Array = tileToSourceDict.get(tileNeighbours)
				#print("Tile Placement: ",tilePlacement)
				#visualTilemap.set_cell(
					#tilePosition + Vector2i(visualLayerOffsetX, visualLayerOffsetY),	# Position to place tile at
					#0,																	# Tile Source ID	
					#Vector2i(tilePlacement[0], tilePlacement[1])						# Atlas Coords of tile to place
				#)
				tilemapLayerArray[editMode].set_cell(
					tilePosition + Vector2i(visualLayerOffsetX, visualLayerOffsetY),	# Position to place tile at
					0,																	# Tile Source ID	
					Vector2i(tilePlacement[0], tilePlacement[1])						# Atlas Coords of tile to place
				)

func GetVisualTileConfig(tilePosition: Vector2i) -> Array:
	#print("Tile Position: ", tilePosition)
	# array used to hold the visual tile config
	var neighbours: Array = [0,0,0,0]
	var neighboursIterator : int = 0
	# the current neighbour tile we are checking
	var neighbour: Vector2i = Vector2i(0,0)

	# Loop through all world map tiles that affect the current visual tile
	for x: int in range(2):
		for y: int in range(2):
			# This gets the atlas coords of the tile that we are currently iterating through
			# if -1, then it means there is no tile there
			neighbour = worldTilemap.get_cell_atlas_coords(tilePosition - visualLayerOffset+Vector2i(x,y))
			
			#print("Neighbour: ",neighbour)

			# If there is a tile there, set that in the config
			if neighbour.y != -1:
				neighbours[neighboursIterator] = 1
				
			neighboursIterator += 1
	#print("Neighbours: ",neighbours)
	return neighbours

func _on_save_tilemap_pressed() -> void:
	if worldTilemap:
		print("Saved Tilemap")
		var worldLayer = worldTilemap

		for child in worldLayer.get_children():
			child.set_owner(worldLayer)

		var savedTilemap = PackedScene.new()
		savedTilemap.pack(worldLayer)
		if tileMapInput.text.get_extension() == "tscn":
			ResourceSaver.save(savedTilemap, tileMapInput.text)
		else:
			print("File type not supported.  Only accept .tscn")
	else:
		print("No Tilemap to Save.")

func SetLayerIndex(layerIndex : int) -> void:
	editModeLoader = layerIndex
	layerLabel.text = str(editModeLoader)

func MouseEnterLayerButton() -> void:
	editMode = -1
	
func MouseExitLayerButton() -> void:
	editMode = editModeLoader

# Loop through all visual layers and create buttons of them
func AddLayerButtons() -> void:
	var layerIndex = 0
	for layer in tilemapLayerArray:
		var layerButton = Button.new()
		layerButton.text = layer.name
		tilemapLayerContainer.add_child(layerButton)
		# Connect signal to control changing editMode
		layerButton.pressed.connect(SetLayerIndex.bind(layerIndex))
		# Connect mouse hover and exit signals
		layerButton.mouse_entered.connect(MouseEnterLayerButton)
		layerButton.mouse_exited.connect(MouseExitLayerButton)
		layerIndex += 1
	for button in fileActionContainer.get_children():
		button.mouse_entered.connect(MouseEnterLayerButton)
		button.mouse_exited.connect(MouseExitLayerButton)

func FileOpened(path : String) -> void:
	tileMapInput.text = path
	var openedTileMap : Node = null
	if ResourceLoader.exists(path):
		openedTileMap = ResourceLoader.load(path).instantiate()
		if openedTileMap:
			self.add_child(openedTileMap)
			worldTilemap = openedTileMap
			# Loop through all children and add
			for child in openedTileMap.get_children():
				tilemapLayerArray.append(child)
			AddLayerButtons()

func _on_open_tilemap_pressed() -> void:
	emit_signal("open", tileMapInput.text)
	var newFileExplorer = fileExplorer.instantiate()
	uiNode.add_child(newFileExplorer)
	# Connect the signal from the file explorer to the NewPath() function
	newFileExplorer.done.connect(FileOpened)
