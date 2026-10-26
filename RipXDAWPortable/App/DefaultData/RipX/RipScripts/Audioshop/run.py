"""
Description: Tool-based Audio Editor. Right-click over rip for menu.
Category: 
Shortcut: 
Level: Advanced
Version: 2.11
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import math
import platform
from PIL import Image, ImageTk

no_tool = 0
draw_pitch_tool = 1	# Native tools from here
edit_unpitched_tool = 2
cutter_tool = 3
join_tool = 4
draw_tool = 5	# Audioshop tools from here
replace_tool = -1
clone_tool = 6#7
pattern_tool = 7#8
smooth_tool = 8#9
remove_sound_tool = 9#10

audioshop_tools = [ \
			[-1, "Audioshop Tools", "", "", "_AUDIOSHOP"],
			[no_tool, "Move/Resize", "cancel_tool_x2.png", "1", "_AUDIOSHOP_MOVE_STRETCH"],
			[edit_unpitched_tool, "Edit Unpitched", "edit_unpitched_tool_x2.png", "2", "_AUDIOSHOP_EDIT_UNPITCHED"],
			[draw_tool, "Draw Sound", "draw_tool_x2.png", "3", "_AUDIOSHOP_DRAW"],
			[cutter_tool, "Split", "cutter_tool_x2.png", "4", "_AUDIOSHOP_CUTTER"],
			[join_tool, "Join", "join_tool_x2.png", "5", "_AUDIOSHOP_JOIN"],
#			[replace_tool, "Replace Sound", "replace_tool_x2.png", "6", "_AUDIOSHOP_REPLACE"],
			[clone_tool, "Clone Pitch/Sound", "clone_tool_x2.png", "7", "_AUDIOSHOP_CLONE"],
			[draw_pitch_tool, "Draw Pitch", "pitch_tool_x2.png", "8", "_AUDIOSHOP_DRAW_PITCH"],
			[pattern_tool, "Apply Pattern", "pattern_tool_x2.png", "9", "_AUDIOSHOP_PATTERN"],
			[smooth_tool, "Smooth Region", "blend_tool_x2.png", "0", "_AUDIOSHOP_BLEND"],
#			[remove_sound_tool, "Remove Sound", "subtract_tool_x2.png", "Shift+1", "_AUDIOSHOP_REMOVE_TIMBRE"]
			]
			
audioshop_tools_tips = [ \
	"Click & drag notes to change position, pitch & duration."
	"Click a note, or click & drag over several notes, to copy, paste, apply effects and much more.",
	"Click & drag to select unpitched sound and edit.",
	"Click & drag to draw notes with the sound selected in the Sound Panel.",
	"Click on notes to split them in two.",
	"Click (& drag) over disconnected notes to join them together for easier editing & cloning.",
#	"Click on notes to replace their sound with the sound selected in the Sound Palette toolbar.",
	"Ctrl+click a note to clone, then click & drag over other notes to clone selected attributes to them.",
	"Click & drag over notes to finely adjust their pitch.",
	"Click & drag over notes to apply patterns to pitch, formant, volume & panning.",
	"Click & drag over notes to smooth out selected attributes.",
#	"Choose a sound to remove by ctrl+clicking a note, then click & drag over notes to remove that sound from them."
	]

number_of_tools = 9#10


def ripscript():

	# Get current view
	view = ripx.current_view
	
	# Default parameters
	edit_note_volume = 0
	mix = PITCH
	effect_function = None

	# Declare variables to be used
	edit_note: Note = None
	edit_note_time = 0.0
	source_note: Note = None
	source_note_time = 0.0
	clone_note: Note = None
	clone_note_time = 0.0
	remove_timbre_note: Note = None
	remove_timbre_note_time = 0.0
	transfer_note: Note = None
	mix_at_click = False
	last_edit_time = None
	current_tool = -1
	transpose_by = 0
	transpose_to_pointer = False
	blend_cache = None
	added_note_at = -1
	set_up_edit_on_motion = False
	edit_on_motion_time = None
	edit_on_motion_pitch = None
	edit_on_motion_x = None
	attribute_combo = None
	pattern_combo = None
	pattern_amplitude = None
	# NB These get set for each tool
	brush_duration = 0.2
	fade_in = 0.05
	fade_out = 0.05
	whole_sound_brush_duration = 10000
	
	# Load settings and set defaults
	settings = Settings()
	settings.add("clone_pitch_changes", 1)
	settings.add("clone_pitch", 0)
	#settings.add("clone_formant_pitch", 0)
	settings.add("clone_timbre", 1)
	#settings.add("clone_volume", 1)
	settings.add("clone_panning", 1)
	settings.add("clone_sync", 0)
	#settings.add("clone_replace", 1.0)
	settings.add("clone_duration", 0.2)
	settings.add("remove_duration", 0.2)
	settings.add("pattern_duration", 0.2)
	settings.add("smooth_duration", 0.2)
	settings.add("remove_timbre_keep_instead", 0)
	settings.add("remove_timbre_remove_to_other", 0)
	settings.add("blend_pitch", 1)
	settings.add("blend_formant_pitch", 0)
	settings.add("blend_timbre", 1)
	settings.add("blend_volume", 0)
	settings.add("blend_panning", 0)
	pattern_attributes = ("Pitch", "Formant", "Volume", "Panning")
	pattern_types = ("Sine", "Square")
	settings.add("pattern_attribute", pattern_attributes[0])
	settings.add("pattern_type", pattern_types[0])
	settings.add("pattern_strength", 0.5)
	settings.add("pattern_period_secs", 0.25)
	settings.add("contrast", 4.0)
	settings.add("contrast_auto", 1)
	settings.add("fine_select", 0)
			
	## EFFECT FUNCTIONS

	def pitch_effect(slices: SliceRange, slice: SimpleSlice, time):
		period = float(pattern_period_secs.get())
		amplitude = pattern_amplitude.get() * 4 # 4 semitone range
		if attribute_combo.get() == "Formant":
			pitch = slice.formant_pitch
		else:
			pitch = slice.pitch
		if pattern_types[pattern_combo.current()] == "Sine":
			pitch += amplitude * math.sin(time*2*math.pi/period)
		elif pattern_types[pattern_combo.current()] == "Square":
			period_state = time % period / period
			if period_state < 0.5:
				pitch += amplitude
			else:
				pitch -= amplitude

	def volume_effect(slices: SliceRange, slice: SimpleSlice, time):
		period = float(pattern_period_secs.get())
		amplitude = pattern_amplitude.get()	# full loudness range
		if pattern_types[pattern_combo.current()] == "Sine":
			slice.volume.loudness += amplitude * math.sin(time*2*math.pi/period)
		elif pattern_types[pattern_combo.current()] == "Square":
			period_state = time % period / period
			if period_state < 0.5:
				slice.volume.loudness += amplitude
			else:
				slice.volume.loudness -= amplitude

	def panning_effect(slices: SliceRange, slice: SimpleSlice, time):
		period = float(pattern_period_secs.get())
		amplitude = pattern_amplitude.get()  * 90	# 90 degree range
		if pattern_types[pattern_combo.current()] == "Sine":
			slice.panning.angle += amplitude * math.sin(time*2*math.pi/period)
		elif pattern_types[pattern_combo.current()] == "Square":
			period_state = time % period / period
			if period_state < 0.5:
				slice.panning.angle += amplitude
			else:
				slice.panning.angle -= amplitude
		
	def blend_effect(slices: SliceRange, slice: SimpleSlice, time):
		nonlocal blend_cache
		if blend_pitch.get() == 1:
			slice.pitch.midi_number = slices.pitch.midi_number
		if blend_formant_pitch.get() == 1:
			slice.formant_pitch.midi_number = slices.formant_pitch.midi_number			
		if blend_timbre.get() == 1:
			if blend_cache is None:
				blend_cache = []
				for h in range(1, len(slice.harmonics) + 1):
					blend_cache.append(slices.harmonic(h).volume.loudness)
			for h in range(1, len(slice.harmonics) + 1):
				slice.harmonic(h).volume.loudness = blend_cache[h-1]
		if blend_volume.get() == 1:
			slice.volume.loudness = slices.volume.loudness
		if blend_panning.get() == 1:
			slice.panning.angle = slices.panning.angle			

	## APPLYING EDIT

	def apply_edit(pointer_time, pointer_pitch):
		
		nonlocal transpose_by
		nonlocal blend_cache
		
		# Mix audio from source_note (or nothing) to edit_note centred at time
						
		# Make local copies of fade so can adjust in case need to clip edit region to note
		this_duration = brush_duration
		this_fade_in = min(this_duration / 2, fade_in)
		this_fade_out = min(this_duration / 2, fade_out)
		volume = 0
		
		# Time region of note to edit
		edit_time = pointer_time - edit_note.start
		
		# How much to expand time to cover any lag from last edit
		start_lag_time = 0
		end_lag_time = 0
		nonlocal last_edit_time
		if last_edit_time is not None:
			if edit_time > last_edit_time:
				start_lag_time = edit_time - last_edit_time
			else:
				if current_tool == draw_tool:# and edit_time < last_edit_time:
					# If dragging back, we want to shorten note, so clear it and re-write
					edit_note.volume.amplitude = 0.0
					start_lag_time = edit_time
				else:
					end_lag_time = last_edit_time - edit_time
		last_edit_time = max(0.0, edit_time)
				
		# Can't actually draw the percussion note - gets added at end
		if edit_note.percussion: return
		
		edit_time_start = edit_time - start_lag_time - this_duration / 2
		# Clip to start of note
		edit_slice_start_adj = 0
		if edit_time_start < 0:
			edit_slice_start_adj = -edit_time_start
			# Adjust this_fade_in so that goes up to max values near edge of note
			this_fade_in = max(0, this_fade_in + edit_time_start)
			edit_time_start = 0
			
		edit_time_end = edit_time + end_lag_time + this_duration / 2
		full_edit_time_end = edit_time_end
		full_this_fade_out = this_fade_out
		# Clip to end of note and adjust this_fade_out accordingly
		if edit_time_end > edit_note.duration:
			this_fade_out = max(0, this_fade_out - (edit_time_end - edit_note.duration))
			edit_time_end = edit_note.duration
			
		# Reset cache for blends so does not recalculate amplitude for every slice
		blend_cache = None
		
		if current_tool == remove_sound_tool:
			## Remove/keep timbre from note
			# What harmonics to update using Sound Palette setting
			harmonic_list = range(1, edit_note.number_of_harmonics + 1)
			if not harmonic_list:
				return None
			# Set up transfer_slice to send removed amplitude to
			transfer_slice = None
			if transfer_note:
				transfer_slice = transfer_note.slice_range(edit_time_start, min(transfer_note.end, edit_time_end), harmonic_list)
			keep_timbre = False
			if remove_timbre_keep_instead.get() != 0: keep_timbre = True
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).remove_timbre(
				source_note.slices, volume=volume, fade_in=this_fade_in, fade_out=this_fade_out,
				remove_other=keep_timbre, remove_to=transfer_slice)

		elif note_exists(source_note):
			## Mix with source note
			source_time = edit_time
			if mix_at_click:
				# Make time relative to source note original click time
				source_time += source_note_time - edit_note_time
			
			# Ensure note not longer than source
			if current_tool == draw_tool:
				edit_time_end = min(source_note.duration, edit_time_end)

			# Update source_note spotlight
			if source_note != edit_note or mix_at_click:
				view.spotlight(source_time=source_note.start+source_time)

			source_slice_start = source_time - start_lag_time - this_duration / 2 + edit_slice_start_adj
			# If need to clip source_slice_start to start of note, need to adjust edit_time_start accordingly
			if source_slice_start < 0:
				edit_time_start -= source_slice_start
				this_fade_in = max(0, this_fade_in + source_slice_start)
				source_slice_start = 0
			source_slice_end = source_time + end_lag_time + this_duration / 2
			# If need to clip source_slice_end to end of note, need to adjust edit_time_end accordingly
			if source_slice_end > source_note.duration:
				edit_time_end = min(edit_time_end, full_edit_time_end - (source_slice_end - source_note.duration))
				this_fade_out = min(this_fade_out, max(0, full_this_fade_out - (source_slice_end - source_note.duration)))
				source_slice_end = source_note.duration
		
			if (mix & TIMBRE) or (mix & VOLUME):
				harmonic_list = range(1, max(edit_note.number_of_harmonics, source_note.number_of_harmonics) + 1)
			else:
				harmonic_list = range(1, edit_note.number_of_harmonics + 1)
			if len(harmonic_list) == 0:
				return None
				
			if transpose_to_pointer:
				transpose_by = pointer_pitch.midi_number - edit_note.slice(edit_note.slice_at(edit_note_time)).pitch.midi_number
			
			# Tools like smooth tool work better updating the edited audio as drag goes along
			# otherwise can get choppy edges due to different smoothing regions
			if current_tool == smooth_tool: edit_note.edits_pause()
			
			# Perform mix
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
				source_note.slice_range(source_slice_start, source_slice_end),
				this_volume=edit_note_volume, volume=volume, fade_in=this_fade_in, fade_out=this_fade_out,
				transpose_by=transpose_by, mix=mix, effect=effect_function)
			
			# And edits back on
			if current_tool == smooth_tool: edit_note.edits_start()
		else:
			## Mix with nothing - ie. lower amplitude or apply pure effect
			# What harmonics to update using Sound Palette setting
			harmonic_list = range(1, edit_note.number_of_harmonics + 1)
			if not harmonic_list:
				return None
			edit_note.slice_range(edit_time_start, edit_time_end, harmonic_list).mix_in(
				this_volume=edit_note_volume, fade_in=this_fade_in, fade_out=this_fade_out)
		
	## EVENT HANDLING
		
	def note_exists(note):
		if note is not None:
			if note:
				return True
			else:
				# E.g. deleted from Rip
				note = None
				return False
		else:
			return False
			
	def mouse_motion(event: ViewEvent):
		nonlocal set_up_edit_on_motion, edit_on_motion_x, brush_duration, fade_in, fade_out

		if not view.has_control: return
		if set_up_edit_on_motion:
			# A background click occurred just before this - add note if moved far enough
			if event.x - edit_on_motion_x >= 2:
				last_edit_time = 0
				set_up_edit_on_motion = False
				set_up_edit(edit_on_motion_time, edit_on_motion_pitch, None)
			
		if current_tool >= draw_tool and current_tool <= smooth_tool:
			# Update spotlight
			# NB Remove timbre has own 'permanent' spotlight and we don't have one for draw tool as new note created
			if current_tool != remove_sound_tool and current_tool != draw_tool:
				view.spotlight(duration=brush_duration,
					fade_in=fade_in,
					fade_out=fade_out,
					volume=float(0-edit_note_volume))
		
			# Perform edit at current time to non-percussion notes
			if note_exists(edit_note):
				pointer_time = event.pointer_time
				if current_tool == draw_tool:
					pointer_time = view.snap_time(time=pointer_time)
				apply_edit(pointer_time, event.pointer_pitch)
				
	def set_up_edit(pointer_time, pointer_pitch, note):
		nonlocal source_note, added_note_at
		nonlocal edit_note
		
		if view.rip is None: return "to_ripx"
		
		# Snap time and pitch to UI guides
		if current_tool == draw_tool:
			pointer_time = view.snap_time(time=pointer_time)
			pointer_pitch = view.snap_pitch(pitch=pointer_pitch, time=pointer_time)

		added_note_at = -1
		if note is None and current_tool == draw_tool:
			# Add note of source note pitch and duration to fill in
			note = view.rip.add_note(at=pointer_time, duration=5.0)
			if note is None:
				edit_note = None
				ripx.pop_up(message="Note could not be added")
				return
			# Set default instrument/effects
			note.apply_defaults()
			added_note_at = pointer_time
			note.pitch.midi_number = pointer_pitch.midi_number
			note.formant_pitch.midi_number = pointer_pitch.midi_number

		if note is not None:
			# Remember note and click time
			nonlocal edit_note_time
			nonlocal last_edit_time
			edit_note = note
			edit_note_time = edit_note.time_at(edit_note.slice_at(pointer_time - edit_note.start))
			last_edit_time = None
			
			# Set up options for current tool
			if set_mix_in_options(added_note_at):
				
				# Select note
				view.rip.selected_notes.clear().include(notes=edit_note)
			
				# Start editing the clicked note
				edit_note.edits_start()
				
				if current_tool != remove_sound_tool:
					# Set up spotlight. Remove Timbre has own permanent one already set up
					if not note_exists(source_note) or (source_note == edit_note and not mix_at_click):
						view.spotlight(source_note=None, source_time=-1)
					else:
						view.spotlight(source_note=source_note, source_time=pointer_time)
				
				# Perform initial edit
				apply_edit(pointer_time, pointer_pitch)
				if current_tool == draw_tool:
					# Do twice to avoid full not flashing up
					apply_edit(pointer_time, pointer_pitch)
				
			else:
				edit_note = None

		else:
			# Allow ripx to process and place cursor etc
			return "to_ripx"
				
	def mouse_click(event: ViewEvent):
		nonlocal source_note, set_up_edit_on_motion, edit_on_motion_time, edit_on_motion_pitch, edit_on_motion_x, edit_note
		if view.rip is None: return
		if not view.has_control: return
		if current_tool == draw_tool:# or (event.note is None and current_tool == clone_tool):
			# Set up for adding note on first mouse motion event so don't add note on a click
			edit_on_motion_time = event.pointer_time
			edit_on_motion_pitch = event.pointer_pitch
			edit_on_motion_x = event.x
			edit_note = None # We no longer allow drawing onto existing notes as Harmonic Editor should be used for this
			set_up_edit_on_motion = True
			#view.set_pointer(pointer=POINTER_CIRCLE)
			return
		elif (current_tool != remove_sound_tool and current_tool != clone_tool) or event.note is not None:
			return set_up_edit(event.pointer_time, event.pointer_pitch, event.note)
		return "to_ripx"
			
	def refresh_note_editor(note: Note):
		if note_exists(note) and hasattr(ripx, "harmonic_editor"):
			ripx.harmonic_editor.refresh(note)
		
	def mouse_release(event: ViewEvent):
		nonlocal edit_note, added_note_at, set_up_edit_on_motion, source_note
		if not view.has_control: return
		#if current_tool == draw_tool or current_tool == clone_tool:
		#	view.set_pointer(pointer=POINTER_DOT)
		if set_up_edit_on_motion:
			# A click on background occurred with no motion
			set_up_edit_on_motion = False
			if edit_note is None:
				# Place cursor
				view.rip.selected_notes.clear()
				# NB Need to set end position first as start cannot be set past end (which will be -1 now)
				view.rip.selected_notes.end = event.pointer_time
				view.rip.selected_notes.start = event.pointer_time
			return "to_ripx"
		elif note_exists(edit_note):
			# End edit on note
			edit_note.edits_end()
			if current_tool == draw_tool and added_note_at >= 0:
				# First check that we didn't drag back to start should delete it
				if last_edit_time == 0:
					edit_note.delete()
					view.rip.selected_notes.clear()
				else:
					if brush_duration < whole_sound_brush_duration:
						# Trim undrawn part
						pointer_time = event.pointer_time
						if current_tool == draw_tool:
							pointer_time = view.snap_time(time=pointer_time)
						edit_note.slice_range(start=pointer_time + brush_duration / 2 - edit_note.start,
							end=edit_note.duration).delete()
					# Play note
					edit_note.play()
			else:
				# Play note
				edit_note.play()		
			# Refresh in note editor if necessary
			refresh_note_editor(edit_note)
			# Clear edit_note
			edit_note = None
			if current_tool != remove_sound_tool:
				view.spotlight(source_note=None, source_time=-1)
		else:
			# Allow ripx to process and place cursor etc
			return "to_ripx"
				
	def mouse_ctrl_click(event: ViewEvent):
		nonlocal source_note, source_note_time, clone_note, clone_note_time, remove_timbre_note, remove_timbre_note_time
		if not view.has_control: return
		if current_tool == clone_tool or current_tool == remove_sound_tool:
			if event.note is not None:
				# Remember note for cloning/timbre
				source_note = event.note
				# Pass time through slice_at and time_at to prevent any rounding errors near a slice centre
				source_note_time = source_note.time_at(source_note.slice_at(event.pointer_time - source_note.start))
				if current_tool == clone_tool:
					clone_note = source_note
					clone_note_time = source_note_time
				elif current_tool == remove_sound_tool:
					remove_timbre_note = source_note
					remove_timbre_note_time = source_note_time
				source_note.play()
				if current_tool == remove_sound_tool:
					duration = source_note.end-source_note.start
					view.spotlight(duration=duration, fade_in=duration/2, fade_out=duration/2, volume=40,
						source_note=source_note, source_time=source_note.start+duration/2)
				
	def mouse_shift_click(event: ViewEvent):
		if not view.has_control: return
		return	# Just prevent Shift-selection by HM UI
		
	def set_tool_pointer():
		if current_tool == draw_tool:
			view.set_pointer(pointer=POINTER_DRAW_SAMPLE_TOOL)
		elif current_tool == clone_tool:
			view.set_pointer(pointer=POINTER_CLONE_TOOL)
		elif current_tool == remove_sound_tool:
			view.set_pointer(pointer=POINTER_REMOVE_SOUND_TOOL)
		elif current_tool == pattern_tool:
			view.set_pointer(pointer=POINTER_PATTERN_TOOL)
		elif current_tool == replace_tool:
			view.set_pointer(pointer=POINTER_REPLACE_SOUND_TOOL)
		elif current_tool == smooth_tool:
			view.set_pointer(pointer=POINTER_SMOOTH_TOOL)

	def ctrl_pressed(event: ViewEvent):
		if current_tool == clone_tool or current_tool == remove_sound_tool:
			# Update pointer
			view.set_pointer(pointer=POINTER_CIRCLE)
		return "to_ripx"
		
	def ctrl_released(event: ViewEvent):
		if current_tool == clone_tool or current_tool == remove_sound_tool:
			# Update pointer
			set_tool_pointer()
		return "to_ripx"
			
	def esc_pressed(event: ViewEvent):
		nonlocal edit_note
		if note_exists(edit_note):
			# Cancel edit
			edit_note.edits_end()
			edit_note = None
			view.spotlight(source_note=None, source_time=-1)
			# Signal to HM to perform any multiple edit undo to return note to original state
			return "break"

		# If not handled, must always signal to Hit'n'Mix to handle Esc presses
		return "to_ripx"
	
	just_set_mode = False
	def control_ended(event: ViewEvent):
		nonlocal just_set_mode
		if not just_set_mode:
			# Deselect tool
			set_tool(no_tool)
			radio_variable.set(no_tool)
			just_set_mode = False
			
	def setup_transfer_note():
		nonlocal transfer_note
		if remove_timbre_remove_to_other.get() == 1:
			# Does a note already exist?
			transfer_note = None
			for note in view.rip.time_range(edit_note.start, edit_note.end).notes:
				if note != edit_note and note.start == edit_note.start and note.end == edit_note.end and note.pitch == edit_note.pitch:
					transfer_note = note
					break
			if not transfer_note:
				# Create silent copy of edit_note
				transfer_note = edit_note.copy_to()
				transfer_note.volume.amplitude = 0
				# Set to instrument name with (Removed) appended so easily selectable afterwards
				transfer_note.instrument = transfer_note.instrument + " (Removed)"

	## TOOL OPTION SETTING
	
	def update_clone_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = clone_duration.get()
		fade_out = fade_in = brush_duration / 3
	
	def update_remove_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = remove_duration.get()
		fade_out = fade_in = brush_duration / 3
	
	def update_pattern_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = pattern_duration.get()
		fade_out = fade_in = brush_duration / 3
	
	def update_smooth_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = smooth_duration.get()
		fade_out = fade_in = brush_duration / 3
		
	def update_draw_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = 0#0.05
		fade_in = fade_out = 0#0.02
	
	def update_replace_duration():
		nonlocal brush_duration, fade_in, fade_out
		brush_duration = 1000
		fade_out = fade_in = 0
		
	# Update brush duration for tool
	def update_brush_duration():
		if current_tool == clone_tool:
			update_clone_duration()
		elif current_tool == remove_sound_tool:
			update_remove_duration()
		elif current_tool == pattern_tool:
			update_pattern_duration()
		elif current_tool == smooth_tool:
			update_smooth_duration()
		elif current_tool == draw_tool:
			update_draw_duration()
		elif current_tool == replace_tool:
			update_replace_duration()
		
	def set_mix_in_options(added_note_at):
		nonlocal edit_note_volume
		nonlocal mix
		nonlocal effect_function
		nonlocal source_note, source_note_time, clone_note, clone_note_time, remove_timbre_note, remove_timbre_note_time
		nonlocal attribute_combo
		nonlocal mix_at_click
		nonlocal transpose_by
		nonlocal transpose_to_pointer
		
		transpose_by = 0
		mix_at_click = False
		transpose_to_pointer = False
		mix = 0

		if current_tool == pattern_tool:
			
			''' Pattern Tool options '''
			edit_note_volume = DB_SILENT	# Means the values are completely overwritten
			if attribute_combo.get() == "Pitch":
				mix |= PITCH
				effect_function = pitch_effect
			elif attribute_combo.get() == "Formant":
				mix |= FORMANT_PITCH
				effect_function = pitch_effect
			elif attribute_combo.get() == "Volume":
				mix |= VOLUME
				effect_function = volume_effect
			elif attribute_combo.get() == "Panning":
				mix |= PANNING
				effect_function = panning_effect
			source_note = edit_note	# We are copying and updating the edited note
			source_note_time = 0.0
		
		elif current_tool == smooth_tool:
			
			''' Blend Tool options '''
			edit_note_volume = DB_SILENT	# Means the values are completely overwritten
			if blend_pitch.get() == 1: mix |= PITCH
			if blend_formant_pitch.get() == 1: mix |= FORMANT_PITCH
			if blend_timbre.get() == 1:
				mix |= TIMBRE | VOLUME  # Otherwise final volume will be zero as edit_note_volume = DB_SILENT
			if blend_volume.get() == 1: mix |= VOLUME
			if blend_panning.get() == 1: mix |= PANNING
			effect_function = blend_effect
			source_note = edit_note	# We are copying and updating the edited note
			source_note_time = 0.0
				
		elif current_tool == draw_tool:
			
			''' Draw Tool options '''
			mix = TIMBRE | VOLUME | FORMANT_PITCH
			effect_function = None
			source_note_time = 0.0
			edit_note_volume = 0.0
			source_note = None
			mix_at_click = True
							
		elif current_tool == clone_tool:
			
			''' Clone Tool options '''
			
			# Set up previous clone note selected
			if note_exists(clone_note):
				source_note = clone_note
				source_note_time = clone_note_time
			
			# NB source_note set by Ctrl+click
			if not note_exists(source_note):
				if platform.system() == "Darwin": # Mac OS X
					ripx.pop_up(message="\u2318-click the note to clone first")
				else:
					ripx.pop_up(message="Ctrl+click the note to clone first")
				return False
			elif source_note.percussion != edit_note.percussion:
				if source_note.percussion:
					ripx.pop_up(message="Cannot paint a note from unpitched sound")
				else:
					ripx.pop_up(message="Cannot paint unpitched sound from a note")
				return False
			edit_note_volume = DB_SILENT # clone_replace.get()
			if clone_pitch_changes.get() == 1:
				mix |= PITCH
				if clone_pitch.get() == 0:
					# Use pitches at click points for better accuracy
					transpose_by = edit_note.slice(edit_note.slice_at(edit_note_time)).pitch.midi_number - \
						source_note.slice(edit_note.slice_at(source_note_time)).pitch.midi_number
			#if clone_formant_pitch.get() == 1: mix |= FORMANT_PITCH
			if clone_timbre.get() == 1: mix |= TIMBRE | VOLUME # NB Now we don't have volume option, always use volume otherwise doesn't sound goo
			#if clone_volume.get() == 1: mix |= VOLUME
			if clone_panning.get() == 1: mix |= PANNING
			if mix == 0:
				ripx.pop_up(message="Please select attributes to clone")
				return False			
			if clone_sync.get() != 1 and added_note_at < 0: mix_at_click = True
			effect_function = None
				
		elif current_tool == remove_sound_tool:
			
			''' Remove Timbre Tool options '''
						
			# Set up previous remove timbre note selected
			if note_exists(remove_timbre_note):
				source_note = remove_timbre_note
				source_note_time = remove_timbre_note_time

			# NB source_note set by Ctrl+click
			if not note_exists(source_note):
				if platform.system() == "Darwin": # Mac OS X
					ripx.pop_up(message="\u2318-click a note to use first")
				else:
					ripx.pop_up(message="Ctrl+click a note to use first")
				return False
			elif source_note.percussion != edit_note.percussion:
				if source_note.percussion:
					ripx.pop_up(message="Cannot subtract unpitched sound from a note")
				else:
					ripx.pop_up(message="Cannot subtract harmonic sound from unpitched sound")
				return False
			
			# Set up transfer note
			setup_transfer_note()
			
		update_brush_duration()
		
		return True
			
	def run_noteeditor(event: Event):
		ripx.run_ripscript("Harmonic Editor")
	def run_chordcreator(event: Event):
		ripx.run_ripscript("Chord Creator")
	def run_replacesound(event: Event):
		ripx.run_ripscript("Replace Sound")
	def run_pitchmapper(event: Event):
		ripx.run_ripscript("Pitch Mapper")
	def run_volumemapper(event: Event):
		ripx.run_ripscript("Volume Mapper")
	def run_panningmapper(event: Event):
		ripx.run_ripscript("Panning Mapper")
	def run_beatmapper(event: Event):
		ripx.run_ripscript("Beat Mapper")
	def run_noiseremoval(event: Event):
		ripx.run_ripscript("Noise Removal")
			
	# Initialise tool option frame
	def initialise_tool_option(tool_index):
		nonlocal tool_options_frame, vcmd
	
		# Vertical positioning of text labels and widgets
		text_row = 1
		widget_row = 0
		widget_pady = 1 * pixel_scale()
		left_pad_x = 3 * pixel_scale()
		
		''' Move / Resize tool '''
		if tool_index == no_tool:
			frame = tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, pady=0, sticky="nw")
			label = frame.add_label(text="Click & drag notes to change position, pitch & duration", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=12, sticky="w", padx=left_pad_x)
			button = frame.add_button(text=" Harmonic Editor ", style='Toolbar.TButton',
				image=ripscript_icon(ripscript="Harmonic Editor", scale=1/4), compound="left",
				tooltip="Run Harmonic Editor to edit the individual harmonics and slices of a note or unpitched sound")
			button.grid(row=widget_row, column=0, sticky="w", padx=2*pixel_scale(), pady=1*pixel_scale())
			button.bind("<Button-1>", run_noteeditor)
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=1, sticky="ns", padx=4*pixel_scale(), pady=0)#widget_pady)
			button = frame.add_button(text=" Map Beats ", style='Toolbar.TButton',
				image=ripscript_icon(ripscript="Beat Mapper", scale=1/4), compound="left",
				tooltip="Run Beat Mapper to apply rhythmic changes to selected bars")
			button.grid(row=widget_row, column=6, sticky="w", padx=2*pixel_scale(), pady=1*pixel_scale())
			button.bind("<Button-1>", run_beatmapper)
			#frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=7, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			#button = frame.add_button(text=" Create Chords ", style='Toolbar.TButton',
			#	image=ripscript_icon(ripscript="Chord Creator", scale=1/4), compound="left",
			#	tooltip="Run Chord Creator to build up chords from a note for the detected key signature")
			#button.grid(row=widget_row, column=8, sticky="w", padx=2*pixel_scale(), pady=3*pixel_scale())
			#button.bind("<Button-1>", run_chordcreator)
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=9, sticky="ns", padx=4*pixel_scale(), pady=0)#widget_pady)
			def fine_select_clicked():
				# Disable slider button if enabled
				if fine_select.get() == 1:
					view.fine_drag_selections = True	# Enable fine-selection
				else:
					view.fine_drag_selections = False # Disable fine-selection
			frame.add_check_button(text=" Fine Selection",
				tooltip="On: Click & drag from background selects only the parts of notes within the region.\n\n"
				"Off: Click & drag selects the whole of notes overlapping the region.\n\n"
				"Tip: Hold down Alt when dragging to toggle this behaviour.",
				variable=fine_select, command=fine_select_clicked).grid(row=widget_row, column=10, padx=tool_options_pad_x, pady=0)#widget_pady)
			fine_select_clicked()
				
		''' Pitch tool '''
		if tool_index == draw_pitch_tool:
			frame = tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, pady=0, sticky="nw")
			label = frame.add_label(text="Click & drag over notes to finely adjust pitch", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, padx=left_pad_x, sticky="nw")
			label = frame.add_label(text=" ")
			label.grid(row=widget_row, column=0, sticky="sw", pady=0*pixel_scale())
			#button = frame.add_button(text=" Map Pitch ", style='Toolbar.TButton',
			#	image=ripscript_icon(ripscript="Pitch Mapper", scale=1/4), compound="left",
			#	tooltip="Run Pitch Mapper to apply linear pitch changes to selected notes")
			#button.grid(row=widget_row, column=0, sticky="w", padx=2*pixel_scale(), pady=1*pixel_scale())
			#button.bind("<Button-1>", run_pitchmapper)
			
		''' Edit Unpitched tool '''
		if tool_index == edit_unpitched_tool:
			frame = tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, pady=0, sticky="w")
			label = frame.add_label(text="Click & drag to select unpitched sound and edit", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=8, padx=left_pad_x, sticky="w")
			#button = frame.add_button(text=" Remove Noise ", style='Toolbar.TButton',
			#	image=ripscript_icon(ripscript="Noise Removal", scale=1/4), compound="left",
			#	tooltip="Run Noise Removal to remove foreground or background noise from a selection")
			#button.grid(row=widget_row, column=0, sticky="w", padx=2*pixel_scale(), pady=1*pixel_scale())
			#button.bind("<Button-1>", run_noiseremoval)
	
			# Contrast
			#frame.add_separator(orient=VERTICAL).grid(row=0, column=1, sticky="ns", padx=2*pixel_scale(), pady=widget_pady)	
			label = frame.add_label(text="Contrast")
			label.grid(row=0, column=0, sticky="w", padx=left_pad_x)#3*pixel_scale())
			current_contrast = contrast.get()
			def contrast_changed(contrast_str):
				nonlocal current_contrast
				to_contrast = contrast.get()
				to_contrast = (int)(to_contrast * 128) / 128
				if to_contrast == current_contrast: return
				current_contrast = to_contrast
				if contrast_auto.get() == 1:
					view.contrast = 0.0	# Auto contrast
				else:
					view.contrast = current_contrast
			contrast_slider = frame.add_scale(from_=1, to=512, orient=HORIZONTAL,
				variable=contrast, command=contrast_changed, length=100*pixel_scale(),
				tooltip="Drag slider to adjust the unpitched level contrast")
			contrast_slider.grid(row=0, column=1, padx=3*pixel_scale(), sticky="w")
			def contrast_auto_clicked():
				# Disable slider button if enabled
				if contrast_auto.get() == 1:
					to_state = 'disabled'
					view.contrast = 0.0	# Auto contrast
				else:
					to_state = 'readonly'
					view.contrast = contrast.get()
				contrast_slider.config(state=to_state)
			frame.add_check_button(text=" Auto",
				tooltip="On: Contrast is set automatically to the levels on screen.\n\n"
				"Off: Contrast is adjusted by the slider setting.",
				variable=contrast_auto, command=contrast_auto_clicked).grid(row=widget_row, column=2, padx=2*pixel_scale(), pady=widget_pady, sticky="w")
			contrast_auto_clicked()
			
		''' Cutter tool '''
		if tool_index == cutter_tool:
			frame = tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, pady=0, sticky="nw")
			label = frame.add_label(text="Click on notes to split in two", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, sticky="nw")
			label = frame.add_label(text=" ")
			label.grid(row=widget_row, column=0, sticky="sw", pady=0*pixel_scale())
			
		''' Join tool '''
		if tool_index == join_tool:
			frame = tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, pady=0, sticky="nw")
			label = frame.add_label(text="Click (& drag) over disconnected notes to join together for easier editing & cloning", foreground='#a0a0a0')
			label.grid(row=text_row, column=0)
			label = frame.add_label(text=" ")
			label.grid(row=widget_row, column=0, sticky="sw", pady=0*pixel_scale())
			
		''' Draw tool '''
		if tool_index == draw_tool:
			frame =  tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, pady=0, sticky="w")
			# Check boxes of attributes to subtract
			label = frame.add_label(text="Click & drag to draw new notes in the selected layer", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=8, sticky="w")
			label = frame.add_label(text=" ")
			label.grid(row=widget_row, column=0, sticky="sw", pady=0*pixel_scale())

		''' Replace tool '''
		#if tool_index == replace_tool:
		#	frame = tool_options_frame[tool_index].add_frame()
		#	frame.grid(row=0, column=0, pady=0, sticky="nw")
		#	label = frame.add_label(text="Click on notes to replace with the selected Sound >>>", foreground='#a0a0a0')
		#	label.grid(row=text_row, padx=left_pad_x, column=0)
		#	button = frame.add_button(text=" Replace Selection ", style='Toolbar.TButton',
		#		image=ripscript_icon(ripscript="Replace Sound", scale=1/4), compound="left",
		#		tooltip="Run Replace Sound to replace all selected notes with the current Sound Palette selection")
		#	button.grid(row=widget_row, column=0, sticky="w", padx=2*pixel_scale(), pady=1*pixel_scale())
		#	button.bind("<Button-1>", run_replacesound)
		
		''' Clone tool '''
		if tool_index == clone_tool:
			frame =  tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, pady=0, sticky="nw")
			# Check boxes of attributes to clone
			if platform.system() == "Darwin": # Mac OS X
				label = frame.add_label(text="\u2318-click note to clone, then click & drag over notes", foreground='#a0a0a0')
			else:
				label = frame.add_label(text="Ctrl+click note to clone, then click & drag over notes", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=6, sticky="nw")
			def clone_pitch_changes_clicked():
				# Disable pitch button if not enabled
				if clone_pitch_changes.get() == 0:
					to_state = 'disabled'
					clone_pitch.set(0)
				else:
					to_state = 'readonly'
				clone_pitch_button.config(state=to_state)
			clone_pitch_changes_button = frame.add_check_button(text=" Pitch Changes", variable=clone_pitch_changes, command=clone_pitch_changes_clicked)
			clone_pitch_changes_button.grid(row=widget_row, column=0, padx=0, pady=widget_pady)
			clone_pitch_button = frame.add_check_button(text=" Pitch", variable=clone_pitch)
			clone_pitch_button.grid(row=widget_row, column=1, padx=tool_options_pad_x, pady=widget_pady)
			clone_pitch_changes_clicked()
			#clone_formant_pitch_button = frame.add_check_button(text=" Formant", variable=clone_formant_pitch)
			#clone_formant_pitch_button.grid(row=widget_row, column=2, padx=tool_options_pad_x, pady=widget_pady)
			clone_timbre_button = frame.add_check_button(text=" Sound", variable=clone_timbre)
			clone_timbre_button.grid(row=widget_row, column=3, padx=tool_options_pad_x, pady=widget_pady)
			#clone_volume_button = frame.add_check_button(text=" Volume", variable=clone_volume)
			#clone_volume_button.grid(row=widget_row, column=4, padx=tool_options_pad_x, pady=widget_pady)
			clone_panning_button = frame.add_check_button(text=" Panning", variable=clone_panning)
			clone_panning_button.grid(row=widget_row, column=5, padx=tool_options_pad_x, pady=widget_pady, sticky="w")
			#frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=6, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			clone_timing_button = frame.add_check_button(text=" From Start",
				tooltip="On: Clone from source note start to destination note start.\n\n"
				"Off: Clone from source mouse click to destination click.", variable=clone_sync)
			clone_timing_button.grid(row=widget_row, column=6, columnspan=1, padx=tool_options_pad_x, pady=widget_pady, sticky="w")
		
			# Duration slider
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=11, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			label = frame.add_label(text="Brush", anchor="w")
			label.grid(row=text_row, column=12, columnspan=1, padx=left_pad_x, sticky="nw")
			def clone_duration_changed(duration_str=None):
				clone_duration_label['text'] = "%.2f s" % clone_duration.get()
				update_clone_duration()
			clone_duration_scale = frame.add_scale(from_=0.01, to=1.0, orient=HORIZONTAL,
				variable=clone_duration, command=clone_duration_changed, length=100*pixel_scale(),
				tooltip="Drag slider to adjust brush duration")
			clone_duration_scale.grid(row=widget_row, column=12, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+1*pixel_scale(), sticky="nw")
			clone_duration_label = frame.add_label(anchor="e", width=6, style='Value.TLabel')
			clone_duration_label.grid(row=text_row, column=13, padx=tool_options_pad_x, sticky="ne")
			clone_duration_label['text'] = "%.2f s" % clone_duration.get()
		
		
		''' Remove Timbre tool '''
		if tool_index == remove_sound_tool:
			frame =  tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, sticky="nw")
			# Check boxes of attributes to subtract
			if platform.system() == "Darwin": # Mac OS X
				label = frame.add_label(text="\u2318-click the sound to remove, then click & drag over notes", foreground='#a0a0a0')
			else:
				label = frame.add_label(text="Ctrl+click the sound to remove, then click & drag over notes", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=8, sticky="nw")
			#frame.add_separator(orient=VERTICAL).grid(row=0, column=1, sticky="ns", padx=tool_options_pad_x)
			frame.add_check_button(text=" Keep Sound Instead",
				tooltip="On: Only the sound of the chosen note is kept.\n\n"
				"Off: The sound of the chosen note is removed.",
				variable=remove_timbre_keep_instead).grid(row=widget_row, column=0, padx=0, pady=widget_pady)
			frame.add_check_button(text=" Remove To Another Note",
				tooltip="On: As sound is removed, it is transferred to a newly created overlapping note so that it is not lost.",
				variable=remove_timbre_remove_to_other).grid(row=widget_row, column=1, padx=tool_options_pad_x, pady=widget_pady)
		
			# Duration slider
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=8, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			label = frame.add_label(text="Brush", anchor="w")
			label.grid(row=text_row, column=9, columnspan=1, padx=tool_options_pad_x, sticky="nw")
			def remove_duration_changed(duration_str=None):
				remove_duration_label['text'] = "%.2f s" % remove_duration.get()
				update_remove_duration()
			remove_duration_scale = frame.add_scale(from_=0.01, to=1.0, orient=HORIZONTAL,
				variable=remove_duration, command=remove_duration_changed, length=100*pixel_scale(),
				tooltip="Drag slider to adjust brush duration")
			remove_duration_scale.grid(row=widget_row, column=9, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+1*pixel_scale(), sticky="nw")
			remove_duration_label = frame.add_label(anchor="e", width=6, style='Value.TLabel')
			remove_duration_label.grid(row=text_row, column=10, padx=tool_options_pad_x, sticky="ne")
			remove_duration_label['text'] = "%.2f s" % remove_duration.get()
		
		''' Pattern tool '''
		if tool_index == pattern_tool:
			nonlocal attribute_combo, pattern_combo, pattern_amplitude
			frame =  tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, pady=0, sticky="nw")
			# Attribute combo
			label = frame.add_label(text="Apply to")
			label.grid(row=text_row, column=1, padx=left_pad_x, sticky="w")
			attribute_combo = frame.add_combo_box(values=pattern_attributes, textvariable=pattern_attribute, width=7+os_spacing, state="readonly")
			attribute_combo.grid(row=widget_row, column=1, padx=left_pad_x, pady=0*pixel_scale(), sticky="w")
			def attribute_selected(event: Event):
				attribute_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
				strength_changed(None)
			attribute_combo.bind("<<ComboboxSelected>>", attribute_selected)	
			# Separator
			#frame.add_separator(orient=VERTICAL).grid(row=0, column=2, sticky="ns", padx=tool_options_pad_x)
			# Pattern combo
			label = frame.add_label(text="Pattern")
			label.grid(row=text_row, column=0, columnspan=1, sticky="nw")
			pattern_combo = frame.add_combo_box(values=pattern_types, textvariable=pattern_type, width=6+os_spacing, state="readonly")
			pattern_combo.grid(row=widget_row, column=0, pady=0*pixel_scale(), sticky="w")
			def pattern_selected(event: Event):
				pattern_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
			pattern_combo.bind("<<ComboboxSelected>>", pattern_selected)
			# Separator
			#frame.add_separator(orient=VERTICAL).grid(row=0, column=5, sticky="ns", padx=tool_options_pad_x)
			# Size slider
			strength_type_label = frame.add_label(text="")
			strength_type_label.grid(row=text_row, column=4, padx=tool_options_pad_x, sticky="w")
			strength_label = frame.add_label(text="", width=3+os_spacing, anchor="e", style='Value.TLabel')
			strength_label.grid(row=text_row, column=5, padx=tool_options_pad_x, sticky="e")
			def strength_changed(strength_str):
				if attribute_combo.get() == "Formant" or attribute_combo.get() == "Pitch":
					strength_type_label['text'] = "Semitones"
					strength_label['text'] = " %.1f" % (pattern_strength.get() * 2.5)
				elif attribute_combo.get() == "Volume":
					strength_type_label['text'] = "dB"
					strength_label['text'] = " %.0f" % (loudness(pattern_strength.get()).db)
				elif attribute_combo.get() == "Panning":
					strength_type_label['text'] = "Degrees"
					strength_label['text'] = " %.0f" % (pattern_strength.get() * 90)
			pattern_amplitude = frame.add_scale(from_=0.01, to=1, orient=HORIZONTAL, variable=pattern_strength, length=100*pixel_scale(),
				command=strength_changed, tooltip="Drag slider to set the amplitude/strength of the pattern")
			pattern_amplitude.grid(row=widget_row, column=4, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+0*pixel_scale(), sticky="w")
			strength_changed(None)
			# Pattern Period
			label = frame.add_label(text="Period", anchor="w")
			label.grid(row=text_row, column=7, columnspan=1, padx=tool_options_pad_x, sticky="w")
			def pattern_period_changed(period_str=None):
				pattern_period_label['text'] = "%.2f s" % pattern_period_secs.get()
			pattern_period_scale = frame.add_scale(from_=0.05, to=1.0, orient=HORIZONTAL,
				variable=pattern_period_secs, command=pattern_period_changed, length=96*pixel_scale(),
				tooltip="Drag slider to adjust how long before the pattern repeats itself")
			pattern_period_scale.grid(row=widget_row, column=7, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+0*pixel_scale(), sticky="nw")
			pattern_period_label = frame.add_label(anchor="e", width=6, style='Value.TLabel')
			pattern_period_label.grid(row=text_row, column=8, padx=tool_options_pad_x, sticky="ne")
			pattern_period_label['text'] = "%.2f s" % pattern_period_secs.get()
		
			# Duration slider
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=9, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			label = frame.add_label(text="Brush", anchor="w")
			label.grid(row=text_row, column=10, columnspan=1, padx=tool_options_pad_x, sticky="nw")
			def pattern_duration_changed(duration_str=None):
				pattern_duration_label['text'] = "%.2f s" % pattern_duration.get()
				update_pattern_duration()
			pattern_duration_scale = frame.add_scale(from_=0.01, to=1.0, orient=HORIZONTAL,
				variable=pattern_duration, command=pattern_duration_changed, length=94*pixel_scale(),
				tooltip="Drag slider to adjust brush duration")
			pattern_duration_scale.grid(row=widget_row, column=10, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+0*pixel_scale(), sticky="nw")
			pattern_duration_label = frame.add_label(anchor="e", width=6, style='Value.TLabel')
			pattern_duration_label.grid(row=text_row, column=11, padx=tool_options_pad_x, sticky="ne")
			pattern_duration_label['text'] = "%.2f s" % remove_duration.get()
		
		''' Blend tool '''
		if tool_index == smooth_tool:
			frame =  tool_options_frame[tool_index].add_frame()
			frame.grid(row=0, column=0, padx=left_pad_x, pady=0, sticky="nw")
			# Blend combo
			label = frame.add_label(text="Click & drag over notes to smooth out selected attributes", foreground='#a0a0a0')
			label.grid(row=text_row, column=0, columnspan=8, sticky="nw")
			blend_pitch_button = frame.add_check_button(text=" Pitch", variable=blend_pitch)
			blend_pitch_button.grid(row=widget_row, column=0, padx=0, pady=widget_pady)
			blend_formant_pitch_button = frame.add_check_button(text=" Formant", variable=blend_formant_pitch)
			blend_formant_pitch_button.grid(row=widget_row, column=1, padx=tool_options_pad_x, pady=widget_pady)
			blend_timbre_button = frame.add_check_button(text=" Timbre", variable=blend_timbre)
			blend_timbre_button.grid(row=widget_row, column=2, padx=tool_options_pad_x, pady=widget_pady)
			blend_volume_button = frame.add_check_button(text=" Volume", variable=blend_volume)
			blend_volume_button.grid(row=widget_row, column=3, padx=tool_options_pad_x, pady=widget_pady)
			blend_panning_button = frame.add_check_button(text=" Panning", variable=blend_panning)
			blend_panning_button.grid(row=widget_row, column=4, padx=tool_options_pad_x, pady=widget_pady)
		
			# Duration slider
			frame.add_separator(orient=VERTICAL).grid(row=widget_row, column=8, sticky="ns", padx=4*pixel_scale(), pady=widget_pady)
			label = frame.add_label(text="Brush", anchor="w")
			label.grid(row=text_row, column=9, columnspan=1, padx=tool_options_pad_x, sticky="nw")
			def smooth_duration_changed(duration_str=None):
				smooth_duration_label['text'] = "%.2f s" % smooth_duration.get()
				update_smooth_duration()
			smooth_duration_scale = frame.add_scale(from_=0.01, to=1.0, orient=HORIZONTAL,
				variable=smooth_duration, command=smooth_duration_changed, length=100*pixel_scale(),
				tooltip="Drag slider to adjust brush duration")
			smooth_duration_scale.grid(row=widget_row, column=9, columnspan=2, padx=tool_options_pad_x, pady=widget_pady+1*pixel_scale(), sticky="nw")
			smooth_duration_label = frame.add_label(anchor="e", width=6, style='Value.TLabel')
			smooth_duration_label.grid(row=text_row, column=10, padx=tool_options_pad_x, sticky="ne")
			smooth_duration_label['text'] = "%.2f s" % remove_duration.get()
			
		if platform.system() == "Darwin": # Mac OS X
			# Fix bug on macOS Tk where tool options not redrawn all away along by adding a large blank label at right
			label = frame.add_label(text="", width=1000)
			label.grid(row=0, column=100, sticky="w")

	def set_tool(tool):
		# Set new tool options
		nonlocal current_tool
		nonlocal source_note
		nonlocal source_note_time
		nonlocal just_set_mode
						
		if tool == no_tool:
			view.end_control()
			view.set_edit_mode(mode=MODE_MOVE_RESIZE)

		current_tool = tool
		for frame in tool_options_frame:
			frame.grid_remove()
		
		# Delay-add frame otherwise not updated on Mac
		def add_frame():
			tool_options_frame[tool].grid(pady=1*pixel_scale())
		if platform.system() == "Darwin": # Mac OS X
			frame.after(1, add_frame)
		else:
			tool_options_frame[tool].grid(pady=1*pixel_scale())
		
		source_note = None
		source_note_time = 0.0
		
		# Set up binds so functions are called for various mouse and key presses
		# We do not want binds for tools no_tool, draw_pitch_tool, edit_unpitched_tool,
		# cutter_tool or join_tool as they are handled completely by the main app
		view.unbind("<All>")
		if tool == draw_tool or tool == replace_tool or tool == clone_tool or tool == pattern_tool or\
			tool == smooth_tool or tool == remove_sound_tool:
			if tool != replace_tool: view.bind("<Motion>", mouse_motion)
			view.bind("<Button-1>", mouse_click)
			view.bind("<Alt-Button-1>", mouse_click)
			view.bind("<ButtonRelease-1>", mouse_release)
			view.bind("<Alt-ButtonRelease-1>", mouse_release)
			view.bind("<Key-Escape>", esc_pressed)
			view.bind("<ControlEnded>", control_ended)
			view.bind("<Control-Button-1>", mouse_ctrl_click)
			view.bind("<Shift-Button-1>", mouse_shift_click)
			view.bind("<Key-Control>", ctrl_pressed)
			view.bind("<KeyRelease-Control>", ctrl_released)

		if tool == draw_pitch_tool:
			# Set Draw Pitch mode
			just_set_mode = True # Prevents ControlEnded event resetting tool
			view.end_control()
			view.set_edit_mode(mode=MODE_DRAW_PITCH)

		elif tool == cutter_tool:
			# Set Cutter mode
			just_set_mode = True # Prevents ControlEnded event resetting tool
			view.end_control()
			view.set_edit_mode(mode=MODE_SPLIT)

		elif tool == edit_unpitched_tool:
			# Set Edit Unpitched mode
			just_set_mode = True # Prevents ControlEnded event resetting tool
			view.end_control()
			view.set_edit_mode(mode=MODE_EDIT_UNPITCHED)

		elif tool == join_tool:
			# Set Join mode
			just_set_mode = True # Prevents ControlEnded event resetting tool
			view.end_control()
			view.set_edit_mode(mode=MODE_JOIN)
			
		elif tool >= 1:
			# Ensure showing normal mode
			# NB If draw_tool it is handled by Audioshop RipScript, but we
			# need to indicate to RipX we have selected this mode so it
			# allows changing of effects and sounds for new notes in current layer
			if tool == draw_tool:
				view.set_edit_mode(mode=MODE_DRAW_SOUND)
			else:
				view.set_edit_mode(mode=MODE_MOVE_RESIZE)
			
			# Update brush duration for tool
			update_brush_duration()

			if tool != remove_sound_tool and tool != draw_tool:
				# Initial spotlight (Timbre has own 'permanent' spotlight and draw_tool doesn't need one)
				view.spotlight(duration=0.05, fade_in=0, fade_out=0, volume=0, selected_only=False, note_type="harmonic",
					source_note=None, source_time=-1)
			elif tool == draw_tool:
				view.spotlight(duration=0.0)
				
			# Take control so mouse clicks and key presses are handled
			view.take_control()
			set_tool_pointer()
		else:
			view.spotlight(duration=0.0)
		
		
	## TOOL WINDOW CREATION
	
	# Create icon bar for quick selection of tools
	# Load button images into global variables to ensure not garbage collected and removed
	global photos
	photos = []
	def add_image(filename):
		global photos
		im = Image.open(ripscript_path(filename))
		scale = pixel_scale() * 0.4 # We are provided x2 sized bitmaps
		im = im.resize((int(im.width * scale), int(im.height * scale)), Image.ANTIALIAS)
		photos.append(ImageTk.PhotoImage(im))
	toolbar = ripx.add_tk_window(sticky='T')
	toolbar.add_separator(orient=VERTICAL).grid(row=0, column=0, sticky="ns", padx=1*pixel_scale())
	toolbar.add_frame().grid(row=0, column=1, sticky="ns", padx=3*pixel_scale())
	radio_variable = IntVar()
	hm_menu_id = None
	def toolbar_button_clicked():
		nonlocal hm_menu_id			
		tool = radio_variable.get()
		if tool >= 0:
			if hm_menu_id >= 0: ripx.select_toolbar_menu_item(id=hm_menu_id, index=tool+1)
			set_tool(audioshop_tools[tool+1][0])
	for tool in range(0, number_of_tools):
		add_image(audioshop_tools[tool+1][2])
		if platform.system() == "Darwin": # Mac OS X
			tooltip = audioshop_tools_tips[tool].replace("Ctrl+", "\u2318-")
		else:
			tooltip = audioshop_tools_tips[tool]
		toolbar.add_radio_button(image=photos[tool], style='Toolbar.TRadiobutton',
			variable=radio_variable, value=tool, command=toolbar_button_clicked,
			tooltip=audioshop_tools[tool+1][1] + " Tool: \n\n" + tooltip).grid(row=int(tool/number_of_tools), column=int(tool%number_of_tools)+2,
			pady=6*pixel_scale())
	toolbar.add_frame().grid(row=0, column=number_of_tools+2, sticky="ns", padx=3*pixel_scale())

	# Create tool window for showing tool options
	tool_options = ripx.add_tk_window(sticky='T')
	if platform.system() == "Darwin": # Mac OS X
		os_spacing = 0
	else:
		os_spacing = 2
	tool_options.minsize(int(532 * pixel_scale()), int(39 * pixel_scale()))
	tool_options.maxsize(int(532 * pixel_scale()), int(39 * pixel_scale()))
	toolbar.minsize(0, int(39 * pixel_scale()))
		
	tool_options_pad_x = 6 * pixel_scale()
	tool_options_pad_y = 4 * pixel_scale()
	
	def validate_float(action, index, value_if_allowed,
		prior_value, text, validation_type, trigger_type, widget_name):
		# action=1 -> insert
		if(action=='1'):
			if text in '0123456789.':
				try:
					float(value_if_allowed)
					return True
				except ValueError:
					return False
			else:
				return False
		else:
			return True
		
	vcmd = (tool_options.register(validate_float), '%d', '%i', '%P', '%s', '%S', '%v', '%V', '%W')
		
	# Separator at left, plus frame to hold all tool frames
	tool_options.add_separator(orient=VERTICAL).grid(row=0, column=0, sticky="ns", padx=1*pixel_scale())
	tool_options.add_frame().grid(row=0, column=1, sticky="ns", padx=2*pixel_scale())
	tool_options_main_frame = tool_options.add_frame()
	tool_options_main_frame.grid(row=0, column=2, sticky="ns")

	# Create tool window frames which can be shown/hidden as each tool selected
	tool_options_frame = []
	tool_options_width = 0
	for tool in range(0, number_of_tools):
		tool_options_frame.append(tool_options_main_frame.add_frame())
		initialise_tool_option(tool)
	
	# Set default tool - none so not confusing when starts up
	set_tool(no_tool)
	radio_variable.set(no_tool)
	
	def tool_options_closed(event):
		settings.save()
		view.unbind("<All>")
	tool_options.bind("<Destroy>", tool_options_closed)

	## ADD TO HIT'N'MIX MENU
	def menu_handler(menu_item_id):
		#if view.rip is not None:
		# Find id in list
		for item_index in range(1, len(audioshop_tools)):
			if audioshop_tools[item_index][0] == menu_item_id:
				radio_variable.set(item_index - 1)
				set_tool(menu_item_id)
				break
	hm_menu_id = ripx.add_toolbar_menu(type=MENU_SELECT_MODE, items=audioshop_tools, handler=menu_handler)
	
