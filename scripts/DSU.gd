# DSU.gd
class_name DSU

var parent: Dictionary = {}
var set_size: Dictionary = {} 

var set_total_area: Dictionary = {} 
var set_color_sum: Dictionary = {}  
var set_is_player_group: Dictionary = {} 

func _print_dsu_structure(operation_description: String = "DSU State"):
	print("--- ", operation_description, " ---")
	var elements = parent.keys()
	elements.sort() 
	var structure_str = "Parent Links: { "
	for i in range(elements.size()):
		var element = elements[i]
		structure_str += str(element) + " -> " + str(parent[element])
		if i < elements.size() - 1:
			structure_str += ", "
	structure_str += " }"
	print(structure_str)
	
	var roots_data_str = "Player Data: { "
	var first_root_entry = true
	
	roots_data_str += "Root " + str(elements[0]) + ": [size=" + str(set_size.get(elements[0], "N/A")) + \
					  ", area=" + str(set_total_area.get(elements[0], "N/A")) + \
					  ", player=" + str(set_is_player_group.get(elements[0], "N/A")) + "]"
	first_root_entry = false
	roots_data_str += " }"
	print(roots_data_str)
	print("----------------------------------------------------------------------------------------------------------------------------------")


func _init():
	pass

func make_set(v_id, initial_radius: float, initial_color: Color, is_player: bool) -> void:
	if not parent.has(v_id):
		parent[v_id] = v_id
		set_size[v_id] = 1
		set_total_area[v_id] = PI * pow(initial_radius, 2)
		set_color_sum[v_id] = initial_color 
		set_is_player_group[v_id] = is_player
		

func find_set(v_id):
	if not parent.has(v_id):
		return null
	if v_id == parent[v_id]:
		return v_id
	
	# Store original parent for verbose logging if desired
	# var original_parent = parent[v_id] 
	
	parent[v_id] = find_set(parent[v_id]) # Path compression
	
	# For very verbose logging of path compression:
	# if parent[v_id] != original_parent:
	# 	print("DSU Path Compression: Node ", v_id, " parent changed from ", original_parent, " to ", parent[v_id])
	
	return parent[v_id]

func union_sets(a_id, b_id):
	var a_root = find_set(a_id)
	var b_root = find_set(b_id)

	if a_root == null or b_root == null:
		printerr("DSU Error: Attempted union with non-existent element: ", a_id if a_root == null else "", " ", b_id if b_root == null else "")
		return null 

	if a_root != b_root:
		var new_root_desc = str(a_root) # Before potential swap
		var merged_root_desc = str(b_root) # Before potential swap

		var new_root = a_root
		var merged_root = b_root
		if set_size[a_root] < set_size[b_root]: 
			new_root = b_root
			merged_root = a_root
			# Update descriptions if swapped
			new_root_desc = str(b_root)
			merged_root_desc = str(a_root)
		
		parent[merged_root] = new_root
		set_size[new_root] += set_size[merged_root]
		set_total_area[new_root] += set_total_area[merged_root]
		set_color_sum[new_root] += set_color_sum[merged_root]
		set_is_player_group[new_root] = set_is_player_group[new_root] or set_is_player_group[merged_root]
		
		if set_size.has(merged_root): set_size.erase(merged_root)
		if set_total_area.has(merged_root): set_total_area.erase(merged_root)
		if set_color_sum.has(merged_root): set_color_sum.erase(merged_root)
		if set_is_player_group.has(merged_root): set_is_player_group.erase(merged_root)
		
		_print_dsu_structure("After union_sets(" + str(a_id) + "["+str(merged_root_desc)+"], " + str(b_id) + "["+str(new_root_desc)+"]) -> New Root: " + str(new_root)) # <<< Print after union
		
		return new_root 
	# else:
		# _print_dsu_structure("After union_sets(" + str(a_id) + ", " + str(b_id) + ") - Already in same set (Root: " + str(a_root) + ")") # Optional
	return a_root 

func get_set_data(v_id) -> Dictionary:
	var root = find_set(v_id)
	if root != null:
		return {
			"root_id": root,
			"size": set_size.get(root, 0),
			"total_area": set_total_area.get(root, 0.0),
			"color_sum": set_color_sum.get(root, Color(0,0,0,0)),
			"is_player": set_is_player_group.get(root, false)
		}
	return {}
