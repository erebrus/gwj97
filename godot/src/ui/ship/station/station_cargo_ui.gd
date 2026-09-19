class_name StationCargoUi extends PanelContainer
@onready var ore_label: Label = %OreLabel
@onready var eth_label: Label = %EthLabel


func _ready():
	Events.station_cargo_updated.connect(_on_station_cargo_updated)


func _on_station_cargo_updated( cargo:Dictionary[Types.Resources, int] ):
	ore_label.text="x %d" % [cargo[Types.Resources.ORE]]
	eth_label.text="x %d" % [cargo[Types.Resources.ETHERIUM]]
