extends Node
#GAME EVENTS

@warning_ignore("unused_signal")
signal game_over
#LEVEL EVENTS
@warning_ignore("unused_signal")
signal level_started(data:Dictionary)



func register_events(manager : MetricsManager):
	manager.register_event_with_payload(level_started)
	
	manager.register_event(game_over)

	
