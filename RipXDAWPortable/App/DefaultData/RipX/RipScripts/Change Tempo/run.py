"""
Description: Change tempo for selected bars, or from cursor if nothing selected. Moves and stretches notes in bars
Category: Tempo
Shortcut: 
Level: Intermediate
Version: 1.31
Copyright:	(c) Hit'n'Mix Ltd 2019-2022
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Load settings and set defaults
	settings = Settings()
	settings.add("bpm", "120")

	# Add a window
	window = ripx.add_tk_window(sticky="NSWE")
	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	
	# Add frame to place widgets in
	frame = window.add_label_frame(text="Enter BPM")
	frame.grid(column=0, columnspan=2, row=2, padx=12, pady=16)
	
	# Set tempo based upon current select
	rip = ripx.current_view.rip
	if rip is None:
		# Get default tempo
		bpm.set(int(round(ripx.tempo)))
	else:
		bar_duration = 2
		if  rip.selected_bar_range is not None:
			bar_duration = rip.bar(rip.selected_bar_range.first).duration
		else:
			bar_duration = rip.bar(number=1).duration
		numerator = rip.time_signature.beats
		if numerator > 3 and numerator % 3 == 0: numerator /= 3
		if bar_duration > 0.1: bpm.set(max(1, min(1000, int(round(60 * numerator / bar_duration)))))	
	
	tempo_entry = frame.add_spin_box(from_=1, to=1000, increment=1, width = 5, textvariable=bpm)
	tempo_entry.grid(column=0, columnspan=2, row=3, padx=pad_x, pady=pad_y, sticky="we")
	tempo_entry.selection_range(0, END)
	tempo_entry.icursor(END)
	tempo_entry.focus_force()
	
	def apply_tempo(bars: BarRange):
		nonlocal rip
			
		tempo = float(bpm.get())
		if tempo < 1 or tempo > 1000:
			ripx.pop_up("Please enter a tempo between 1 and 1000")
			return
		
		if bars is None:
			
			# Apply to default tempo
			ripx.tempo = tempo
			
		else:
		
			# Read Rip time signature
			numerator = rip.time_signature.beats
			if numerator > 3 and numerator % 3 == 0: numerator /= 3
			bar_duration = 60 * numerator / tempo;
				
			for bar in bars:
				
				# Show a progress bar and exit if user presses Escape
				if not ripx.interact('Applying Tempo', bar.progress):
					return
					
				# Set bar duration
				duration_before = bar.duration
				bar.stretch(duration=bar_duration)
				
				# Adjust selection/loop markers
				def update_time(time, duration_before, bar):
					if time > bar.start:
						if time < bar.end - (bar_duration - duration_before):
							time += (bar_duration - duration_before) * (time - bar.start) / duration_before
						else:
							time += bar_duration - duration_before
				update_time(rip.loop_time_range.start, duration_before, bar)
				update_time(rip.loop_time_range.end, duration_before, bar)
				update_time(rip.selected_time_range.start, duration_before, bar)
				update_time(rip.selected_time_range.end, duration_before, bar)
		
		# Close window when finished
		window.winfo_toplevel().destroy()
		
	def apply_to_selection(event: Event):
		nonlocal rip
		# Show message if rip not open or nothing selected (optional)
		if rip is not None:
			rip = ripx.current_view.rip
			if rip is None: # Check in case closed rip since
				ripx.pop_up("Please open a rip first")
				return

		if rip is None:
			bars = None # Apply to default tempo
		elif rip.selected_time_range is not None and rip.selected_time_range.end > 0 and rip.selected_time_range.end > rip.selected_time_range.start and \
			rip.selected_bar_range is not None and rip.selected_bar_range.last >= 1 and rip.selected_bar_range.last >= rip.selected_bar_range.first:
			bars = rip.selected_bar_range
		elif rip.selected_bar_range is not None:
			bars = rip.bar_range(rip.selected_bar_range.first, len(rip.bars))
		else:
			bars = rip.bars
		apply_tempo(bars)
		
	def apply_to_all(event: Event):
		nonlocal rip
		# Show message if rip not open or nothing selected (optional)
		if rip is None:
			# If was originally None, UI is set to update default tempo
			apply_tempo(None)
		else:
			rip = ripx.current_view.rip
			if rip is None: # Check in case closed rip since
				ripx.pop_up("Please open a rip first")
				return
			apply_tempo(rip.bars)

	# Add tip
	entry = window.add_label(text="Tip: Drag tops of bar markers to", anchor="center")
	entry.grid(column=0, columnspan=2, row=3, padx=0, pady=0, sticky="we")
	entry = window.add_label(text="adjust without stretching audio", anchor="center")
	entry.grid(column=0, columnspan=2, row=4, padx=0, pady=0, sticky="we")

	# Add Apply button
	if rip is None:
		apply_button = window.add_button(text="                    ")
	else:
		apply_button = window.add_button(text=" Apply To Selection ")
	apply_button.grid(column=0, row=5, padx=16, pady=pad_y*3, sticky=(E))
	apply_button.bind("<Button-1>", apply_to_selection)
	if rip is None:
		apply_button.config(state='disabled')
		apply_button = window.add_button(text=" Apply Default ")
	else:
		apply_button = window.add_button(text=" Apply To Rip ")
	apply_button.grid(column=1, row=5, padx=16, pady=pad_y, sticky=(E))
	apply_button.bind("<Button-1>", apply_to_all)
	tempo_entry.bind("<Return>", apply_to_all)
	
	# Bind window destroy event to the window_destroy function to
	# save settings when window closed
	def window_destroy(event):
		if event.widget != window: return
		settings.save()
	window.winfo_toplevel().bind("<Destroy>", window_destroy)

	# Cancel window
	def cancel(event: Event):
		window.winfo_toplevel().destroy()
		return "break"
	window.winfo_toplevel().bind("<Key-Escape>", cancel)
