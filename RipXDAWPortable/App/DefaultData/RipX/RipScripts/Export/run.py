"""
Description: Export a Rip In Various File Formats
Category: File
Shortcut:
Level: Intermediate
Version: 1.32
Copyright:	(c) Hit'n'Mix Ltd 2019-2023
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

import os
import shutil
import json
import platform
from tkinter import filedialog
from tkinter import messagebox

	
def ripscript():
		
	file_types = [ FLAC16, FLAC32, MIDI, MIDINOTES, MP3, OGG32, STEM, WAV16, WAV24, WAV32 ]
	file_type_exts = [ ".flac",".flac", ".mid", ".mid",".mp3",".ogg", ".stem.mp4",".wav",".wav",".wav" ]
	file_type_names = [ "FLAC 16-bit (.flac)","FLAC 32-bit (.flac)","MIDI - Detailed (.mid)","MIDI - Simple (.mid)","MP3 (.mp3)","OGG 32-bit (.ogg)", "Stem (.stem.mp4)", \
			"WAV 16-bit (.wav)","WAV 24-bit (.wav)","WAV 32-bit (.wav)"]
	if platform.system() == "Darwin": # Mac OS X:
		file_types += [ MP4, MOV ]
		file_type_exts += [ ".mp4", ".mov" ]
		file_type_names += [ "MPEG-4 Movie (.mp4)", "QuickTime Movie (.mov)" ]
	sample_rates = [192000, 96000, 88200, 64000, 48000, 44100, 32000, 22050, 0 ]
	sample_rate_names = ["192 kHz", "96 kHz", "88.2 kHz", "64 kHz", "48 kHz", "44.1 kHz", "32 kHz", "22.05 kHz", "Same As Source"]
	channel_options = [1, 2]
	channel_option_names = ["Mono", "Stereo"]
			
	# Create window
	window = ripx.add_tk_window(sticky='NSWE')
	pad_x = 8 * pixel_scale()
	pad_y = 6 * pixel_scale()

	# Load settings and set defaults
	settings = Settings()
	settings.add("folder_name", "")
	settings.add("file_type", file_type_names[7]) # Default WAV16
	settings.add("sample_rate", sample_rate_names[5]) # Default 44.1
	settings.add("channels", channel_option_names[1]) # Default stereo
	settings.add("selection", "all")
	settings.add("separation", "none")
	settings.add("filter_notes", 1)
	separation_forced = StringVar()
	separation_forced.set("none")

	## Name & folder label frame
	file_frame = window.add_label_frame(text=" File Name & Folder ")
	file_frame.grid(column=0, row=0, padx=pad_x, pady=pad_y, sticky="we")
	
	# Filename entry
	global file_name
	file_name = StringVar()
	if ripx.current_view.rip is not None: file_name.set(ripx.current_view.rip.name)
	file_name_entry = file_frame.add_entry(textvariable=file_name, width=64)
	file_name_entry.grid(column=0, row=0, columnspan=2, padx=pad_x, pady=pad_y, sticky="we")
	
	# Folder display and selection button
	def select_folder(event: Event):
		folder = filedialog.askdirectory(initialdir=folder_name.get(), title="Select Export Folder")
		if folder != "":
			folder_name.set(folder)
	if folder_name.get() == "":
		if ripx.current_view.rip is not None:
			folder_name.set(os.path.dirname(ripx.current_view.rip.file_name))
		else:
			select_folder(None)
	folder_entry = file_frame.add_entry(textvariable=folder_name, state="readonly", width=64)
	folder_entry.grid(column=0, row=1, padx=pad_x, pady=pad_y, sticky="we")
	folder_button = file_frame.add_button(text=" Select Folder ")
	folder_button.grid(column=1, row=1, padx=pad_x, pady=pad_y, sticky="we")
	folder_button.bind("<Button-1>", select_folder)
	
	## Format frame
	format_frame = window.add_label_frame(text=" File Format ")
	format_frame.grid(column=0, row=1, padx=pad_x, pady=pad_y, sticky="we")
	
	# File type combo
	file_type_combo = format_frame.add_combo_box(values=file_type_names, textvariable=file_type, state="readonly")
	file_type_combo.grid(column=0, row=0, padx=pad_x, pady=pad_y)
	def file_type_selected(event: Event):
		# Sample rate/channels valid options?
		file_type_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
		file_type_id = file_types[file_type_combo.current()]
		if file_type_id == RIP or file_type_id == MP3 or file_type_id == MIDI or file_type_id == MIDINOTES or file_type_id == STEM:
			to_state = 'disabled'
		else:
			to_state = 'readonly'
		sample_rate_combo.config(state=to_state)
		channels_combo.config(state=to_state)
		if file_type_id == MIDI or file_type_id == MIDINOTES:
			midi_filter_notes_button.grid(column=1, row=0, padx=0, pady=0)
		else:
			midi_filter_notes_button.grid_remove()
		# Selection valid options?
		if file_type_id == RIP or file_type_id == MP4 or file_type_id == MOV:
			selection_button_all.grid_remove()
			selection_button_selection.grid_remove()
			selection_button_loop.grid_remove()
		else:
			selection_button_all.grid(column=0, row=0, padx=pad_x, pady=pad_y)
			selection_button_selection.grid(column=1, row=0, padx=pad_x, pady=pad_y)	
			selection_button_loop.grid(column=2, row=0, padx=pad_x, pady=pad_y)	
		# Separate layers valid option?
		if file_type_id == STEM or file_type_id == RIP or file_type_id == MP4 or file_type_id == MOV:
			separation_button_none_forced.grid(column=0, row=0, padx=pad_x, pady=pad_y)
			separation_button_none.grid_remove()
			separation_button_stems.grid_remove()
			separation_button_layers.grid_remove()
		else:
			separation_button_none_forced.grid_remove()
			separation_button_none.grid(column=0, row=0, padx=pad_x, pady=pad_y)
			separation_button_stems.grid(column=1, row=0, padx=pad_x, pady=pad_y)
			separation_button_layers.grid(column=2, row=0, padx=pad_x, pady=pad_y)
	file_type_combo.bind("<<ComboboxSelected>>", file_type_selected)
	
	# Frame for showing sample rate & channels over a single grid column (so can swap with a tip)
	format_subframe = format_frame.add_frame()
	format_subframe.grid(column=1, row=0, padx=0, pady=0)
	
	# Sample rate combo
	sample_rate_combo = format_subframe.add_combo_box(values=sample_rate_names, textvariable=sample_rate, state="readonly")
	sample_rate_combo.grid(column=0, row=0, padx=pad_x, pady=pad_y)
	def sample_rate_selected(event: Event):
		sample_rate_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
	sample_rate_combo.bind("<<ComboboxSelected>>", sample_rate_selected)	
	
	# Channels combo
	channels_combo = format_subframe.add_combo_box(values=channel_option_names, textvariable=channels, state="readonly")
	channels_combo.grid(column=1, row=0, padx=pad_x, pady=pad_y)
	def channels_selected(event: Event):
		channels_combo.selection_clear() # To prevent selected text that shouldn't apply to read-only combo
	channels_combo.bind("<<ComboboxSelected>>", channels_selected)
	
	# Filter Notes option for improved MIDI export
	midi_filter_notes_button = format_frame.add_check_button(text=" Filter Notes", variable=filter_notes)
	midi_filter_notes_button.grid(column=1, row=0, padx=pad_x, pady=pad_y, sticky="w")

	## What To Export frame
	selection_frame = window.add_label_frame(text=" What To Export ")
	selection_frame.grid(column=0, row=2, padx=pad_x, pady=pad_y, sticky="we")
	
	## Files To Export frame
	files_frame = window.add_label_frame(text=" Files To Create ")
	files_frame.grid(column=0, row=3, padx=pad_x, pady=pad_y, sticky="we")

	# Separation options
	separation_button_none = files_frame.add_radio_button(text=" Single File(s)",
		tooltip="Creates a single file containing all audible Layers.",
		variable=separation, value="none")
	separation_button_none.grid(column=0, row=0, padx=pad_x, pady=pad_y)
	separation_button_stems = files_frame.add_radio_button(text=" Separate Stems",
		tooltip="Creates a folder of given File Name and saves separate files for each Stem Group assigned by the audible Layers.\n\n"
		"The Stem Group for a Layer can be selected from the Layers Panel menu.",
		variable=separation, value="stems")
	separation_button_stems.grid(column=1, row=0, padx=pad_x, pady=pad_y)
	separation_button_layers = files_frame.add_radio_button(text=" Separate Layers",
		tooltip="Creates a folder of given File Name and saves separate files for each audible Layer.",
		variable=separation, value="layers")
	separation_button_layers.grid(column=2, row=0, padx=pad_x, pady=pad_y)
	# Version of Single File for when no other options, which doesn't affect setting for other file types
	separation_button_none_forced = files_frame.add_radio_button(text=" Single File",
		tooltip="Creates a single file containing all audible Layers.",
		variable=separation_forced, value="none")

	# Radio options
	def selection_button_clicked():
		nonlocal separation_button_none
		if selection.get() == "rips":
			file_name_entry.config(state='disabled')
			separation_button_none.config(text=" Single File(s)")
		else:
			file_name_entry.config(state='normal')
			separation_button_none.config(text=" Single File")
	selection_button_clicked()	
	selection_button_all = selection_frame.add_radio_button(text="Full Rip", variable=selection, value="all", command=selection_button_clicked)
	selection_button_all.grid(column=0, row=0, padx=pad_x, pady=pad_y)
	selection_button_selection = selection_frame.add_radio_button(text="Selected Time/Notes", variable=selection, value="selection", command=selection_button_clicked)
	selection_button_selection.grid(column=1, row=0, padx=pad_x, pady=pad_y)	
	selection_button_loop = selection_frame.add_radio_button(text="Loop Region", variable=selection, value="loop", command=selection_button_clicked)
	selection_button_loop.grid(column=2, row=0, padx=pad_x, pady=pad_y)	
	selection_button_rips = selection_frame.add_radio_button(text="Selected Rips", variable=selection, value="rips", command=selection_button_clicked)
	selection_button_rips.grid(column=3, row=0, padx=pad_x, pady=pad_y)	

	# Set disabled items
	file_type_selected(None)

	# Export button and functionality
	export_button = window.add_button(text=" Export ")
	export_button.grid(column=0, row=4, padx=pad_x, pady=pad_y, sticky=(E))
	exporting = False
	def export_rip(event: Event):
		nonlocal exporting
		
		if exporting: return
		exporting = True

		if folder_name.get() == "":
			select_folder(None)
			if folder_name.get() == "":
				exporting = False
				return

		rip = ripx.current_view.rip
		if selection.get() != "rips" and rip is None:
			ripx.pop_up("Open a rip to export")
			exporting = False
			return

		# Get chosen file type
		file_type_id = file_types[file_type_combo.current()]

		# Check selection choice valid
		## NB No selection currently for MP4 or MOV files
		if selection.get() == "all" or selection.get() == "rips" or file_type_id == MP4 or file_type_id == MOV:
			selection_group = 0	# All
		elif selection.get() == "selection":
			if rip.selected_notes is None or rip.selected_notes.end < 0:
				selection_group = 0
			else:
				selection_group = rip.selected_notes
		elif selection.get() == "loop":
			if rip.loop_time_range is None or rip.loop_time_range.end < 0 or rip.loop_time_range.end < rip.loop_time_range.start + 0.001:
				ripx.pop_up("Set the loop markers or make a different selection")
				exporting = False
				return
			else:
				selection_group = rip.loop_time_range
			
		channels = channels_combo.current()
	
		# Options
		options = 0
		if file_type_id != STEM and file_type_id != RIP and file_type_id != MP4 and file_type_id != MOV:
			if separation.get() == "layers": options |= EXPORT_OPTION_SEPARATE_LAYERS
			elif separation.get() == "stems": options |= EXPORT_OPTION_SEPARATE_STEMS
		if file_type_id == MIDINOTES or file_type_id == MIDI:
			if filter_notes.get() == 1: options |= EXPORT_OPTION_SEPARATE_FILTERNOTES

		if selection.get() == "rips":
			# Export selected rips
			if len(ripx.riplist.selected_rips) == 0:
				ripx.pop_up("Select rips to export from the Rips panel")
				exporting = False
				return

		def export_file(rip: Rip, filename: str, ext: str, this_sample_rate: int):
			nonlocal options, file_type_id
			
			# Is file type valid for the current rip?
			if file_type_id == MP4 or file_type_id == MOV:
				if rip.video_file_name is None:
					ripx.pop_up(rip.name + " does not contain any video, please select an audio format")
					return EXPORT_ERROR

			# Sample rate/channels
			if file_type_id != RIP and file_type_id != MIDI and file_type_id != MIDINOTES:
				if this_sample_rate == 0: this_sample_rate = rip.source_sample_rate
				if this_sample_rate == 0:
					ripx.pop_up(rip.name + " has an unknown source sample rate.\n\nPlease select a sample rate")
					return EXPORT_ERROR
			else:
				# MIDI & RIP don't use sample rates as not waveform based
				this_sample_rate = 0

			# Check whether file exists and whether to delete
			if options & (EXPORT_OPTION_SEPARATE_LAYERS | EXPORT_OPTION_SEPARATE_STEMS):
				# We need to save to a given folder
				file_path = os.path.join(folder_name.get(), filename)
				if os.path.isdir(file_path):
					if messagebox.askyesno("Warning",rip.name + " - A folder already exists with this name.\n\nWould you like to OVERWRITE the ENTIRE FOLDER INCLUDING CONTENTS?"):
						try:
							shutil.rmtree(file_path)
						except:
							messagebox.showerror(message="The folder could not be overwritten.")
							return EXPORT_ERROR
					else:
						return EXPORT_ERROR
				if os.path.isfile(file_path):
					if messagebox.askyesno("Warning", rip.name + " - A file already exists with this name.\n\nWould you like to overwrite it?"):
						try:
							os.remove(file_path)
						except:
							messagebox.showerror(message="The file could not be overwritten.")
							return EXPORT_ERROR
					else:
						return EXPORT_ERROR
			else:
				# We need to save to a given file
				file_path = os.path.join(folder_name.get(), filename + ext)
				if os.path.isdir(file_path):
					ripx.pop_up(rip.name + " - A folder with this name already exists.\n\nPlease check it and remove first if required.")
					return EXPORT_ERROR
				if os.path.isfile(file_path):
					if messagebox.askyesno("Warning",rip.name + " - A file already exists with this name.\n\nWould you like to overwrite it?"):
						try:
							os.remove(file_path)
						except:
							messagebox.showerror(message="The file could not be overwritten.")
							return EXPORT_ERROR
					else:
						return EXPORT_ERROR
			
			# Export
			result = rip.export(
				file=file_path,
				type=file_type_id,
				sample_rate=this_sample_rate,
				channels=channel_options[channels],
				selection=selection_group,
				options=options)
				
			if result != EXPORT_SUCCESS:
				if result == EXPORT_FILE_EXISTS:
					ripx.pop_up(rip.name + " - File already exists")
				elif result == EXPORT_VIDEO_FORMAT_UNAVAILABLE:
					ripx.pop_up(rip.name + " - This video format is not available for the source video format")
				else:
					ripx.pop_up(rip.name + " - There was a problem exporting")
					
			return result
		
		# Get filename
		filename = file_name.get()
		ext = file_type_exts[file_type_combo.current()]
		selected_sample_rate = sample_rates[sample_rate_combo.current()]
						
		# Save state
		settings.save()	
		window.winfo_toplevel().destroy()

		# Export
		if selection.get() == "rips":
			# Export selected rips
			for selected_rip in ripx.riplist.selected_rips:
				
				# Show a progress bar and exit if user presses Escape
				if not ripx.interact('Exporting Selected Rips', 0):#selected_rip.progress): # selected_rip.progress doesn't always work
					break

				# Export selected tip
				result = export_file(selected_rip, os.path.normpath(selected_rip.name), ext, selected_sample_rate)
				if result != EXPORT_SUCCESS:
					break
		else:
			# Export current rip
			if filename == "": filename = ripx.current_view.rip.name
			result = export_file(ripx.current_view.rip, os.path.normpath(filename), ext, selected_sample_rate)

		exporting = False
			
	def export_cancel(event: Event):
		window.winfo_toplevel().destroy()
		return "break"
		
	export_button.bind("<Button-1>", export_rip)
	# Also press Enter to Export
	window.winfo_toplevel().bind("<Key-Return>", export_rip)
	# Cancel window
	window.winfo_toplevel().bind("<Key-Escape>", export_cancel)

