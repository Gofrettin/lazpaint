# Split RGB channels
from lazpaint import image, layer, tools, colors

image.do_begin()

layer_id = layer.get_id()
layer.duplicate()
layer.new()
tools.choose(tools.FLOOD_FILL)
tools.set_fore_color(colors.BLUE)
tools.mouse((0,0))
layer.set_blend_op(layer.BLEND_DARKEN)
layer.merge_over()
layer.set_blend_op(layer.BLEND_LIGHTEN)
layer.set_name("Blue channel")

layer.select_id(layer_id)
layer.duplicate()
image.move_layer_index(image.get_layer_index(), image.get_layer_count())
layer.new()
tools.choose(tools.FLOOD_FILL)
tools.set_fore_color(colors.LIME)
tools.mouse((0,0))
layer.set_blend_op(layer.BLEND_DARKEN)
layer.merge_over()
layer.set_blend_op(layer.BLEND_LIGHTEN)
layer.set_name("Green channel")

layer.select_id(layer_id)
layer.duplicate()
image.move_layer_index(image.get_layer_index(), image.get_layer_count())
layer.new()
tools.choose(tools.FLOOD_FILL)
tools.set_fore_color(colors.RED)
tools.mouse((0,0))
layer.set_blend_op(layer.BLEND_DARKEN)
layer.merge_over()
layer.set_blend_op(layer.BLEND_LIGHTEN)
layer.set_name("Red channel")

layer.select_id(layer_id)
layer.set_visible(False)

image.do_end()
