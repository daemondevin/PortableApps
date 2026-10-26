"""
Description: Shows tempo for the bar under the pointer
Category: Tempo
Shortcut: 
Level: Intermediate
Version: 1.11
Copyright:	(c) Hit'n'Mix Ltd 2019-2021
Author:		Martin Dawe
License: 	Feel free to create an editable copy of this RipScript and base
			your own creations on it. Email to ripscripts@hitnmix.com and
			we will consider featuring it on the RipScripts page at
			hitnmix.com/ripscripts/
"""

def ripscript():
	
	# Add a toolbar window
	window = ripx.add_tk_window(sticky="T")

	pad_x = 6 * pixel_scale()
	pad_y = 4 * pixel_scale()
	
	window.add_separator(orient=VERTICAL).grid(row=0, rowspan=2, column=0, sticky="ns", padx=1*pixel_scale())

	label = window.add_label(text="Tempo")
	label.grid(row=1, column=1, padx=pad_x, sticky="w")
	tempo_label = window.add_label(width=12, style='Value.TLabel')
	tempo_label.grid(row=0, column=1, sticky='WE', padx=pad_x)
	
	label = window.add_label(text="Time Signature")
	label.grid(row=1, column=2, padx=pad_x, sticky="w")
	timesig_label = window.add_label(width=12, anchor="w", style='Value.TLabel')
	timesig_label.grid(row=0, column=2, sticky=E, padx=pad_x)

	# Get the current view that is being edited
	view = ripx.current_view
	
	# Declare function that will update labels with info
	# about what is under the mouse pointer
	def mouse_motion(event: ViewEvent):
		
		# Update info about note we might be over
		rip = ripx.current_view.rip
		if rip is None:
			tempo_label.config(text="")
			timesig_label.config(text="")
		else:
	
			# Read Rip time signature
			timesig_top = rip.time_signature.beats
			timesig_bot = rip.time_signature.beat_unit
			timesig_label.config(text="%d/%d" % (timesig_top, timesig_bot))
			time = max(0,  event.pointer_time - 0.05) # Adjust so that shows for left-hand bar when dragging
			bar = rip.bar_at(time=time)
			if bar is not None:
				tempo = 60 * (4 * timesig_top / timesig_bot) / bar.duration;
				tempo_label.config(text="%.1f BPM" % (tempo))
			else:
				tempo_label.config(text="")

	# 'Bind' mouse motion event to the mouse_motion function we declared
	# This means 'mouse_motion' gets called every time mouse is moved
	view.bind("<Motion>", mouse_motion)
	
	# Declare function to call when window is closed
	def window_destroy(event):
		if event.widget != window: return
		view.unbind("<All>")
	
	# Bind window destroy evetn to the window_destroy function to stop
	# handling mouse motion events and stop RipScript when window closed
	window.winfo_toplevel().bind("<Destroy>", window_destroy)
