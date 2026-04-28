@tool
extends EditorScript

## Import LoY shop data from shops.xml → ShopDefinition .tres files

func _run() -> void:
	var source = "res://../../Downloads/legends-of-yore-export/data/shops/shops.xml"
	var file = FileAccess.open(source, FileAccess.READ)
	if not file:
		print("ERROR: Cannot open " + source)
		return

	var xml = file.get_as_text()
	file.close()

	var out_dir = "res://resources/shops/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var count = 0
	var pos = 0
	while true:
		var shop_start = xml.find("<shop ", pos)
		if shop_start < 0:
			break
		# Find end of shop block
		var shop_end = xml.find("</shop>", shop_start)
		if shop_end < 0:
			shop_end = xml.find("/>", shop_start)
			if shop_end < 0:
				break
			shop_end += 2
		else:
			shop_end += 7

		var block = xml.substr(shop_start, shop_end - shop_start)
		if shop and shop.id != "":
			ResourceSaver.save(shop, out_dir + shop.id + ".tres")
			count += 1

		pos = shop_end

	print("Imported " + str(count) + " shops")

func _parse_shop(block: String) -> ShopDefinition:
	var shop = ShopDefinition.new()

	# Parse shop tag attributes
	var tag_end = block.find(">")
	var tag = block.substr(0, tag_end + 1) if tag_end >= 0 else block

	shop.id = _get_attr(tag, "id")
	shop.shop_type = _get_attr(tag, "type")
	shop.shop_name = _get_attr(tag, "name")
	shop.portrait = int(_get_attr(tag, "portrait"))
	shop.title = _get_attr(tag, "title")
	shop.welcome = _get_attr(tag, "welcome")
	shop.nomoney = _get_attr(tag, "nomoney")
	shop.buy_text = _get_attr(tag, "buy")
	shop.sell_text = _get_attr(tag, "sell")

	# Parse stock items
	var stock_items: Array = []
	var spos = 0
	while true:
		var si = block.find("<stock ", spos)
		if si < 0:
			break
		var se = block.find("/>", si)
		if se < 0:
			break
		var stock_tag = block.substr(si, se - si + 2)
		var item_name = _get_attr(stock_tag, "type")
		var required_quest = _get_attr(stock_tag, "if")
		if item_name != "":
			stock_items.append({"item_name": item_name, "required_quest": required_quest})
		spos = se + 2

	shop.stock = stock_items
	return shop

func _get_attr(tag: String, attr_name: String) -> String:
	var search = " " + attr_name + '="'
	var start = tag.find(search)
	if start < 0:
		search = '\t' + attr_name + '="'
		start = tag.find(search)
	if start < 0:
		return ""
	start += search.length()
	var end = tag.find('"', start)
	if end < 0:
		return ""
	return tag.substr(start, end - start)
