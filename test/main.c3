import std::io;
import dxml;

fn void! test(int i){
	io::printfn("[TEST %d]", i);
	XMLDocument doc;
	defer doc.free();
	DString dstr;
	dstr.append("test");
	dstr.appendf("%d.xml", i);
	// doc.load_file(dstr.str_view())!!;
	File file = file::open(dstr.str_view(), "rb")!;
	doc.load_from_stream(&file)!;
	file.close()!;
	dstr.clear();
	dstr.appendf("outtest%d.xml", i);

	File file2 = file::open(dstr.str_view(), "wb")!!;
	doc.write_to_stream(&file2)!;
	file2.close()!;

	dstr.free();

	io::printf("%s", doc);
	io::printfn("[COMPLETE %d]", i);
}



fn void main(String[] args)
{
	// for(int i = 1; i < 4; i++) test(i)!!;
	unit_test();
}


fn void unit_test(){
	XMLDocument doc;
	doc.load_file("test4.xml")!!;
	assert(doc.root != null);
	assert_str_equal(doc.encoding, "UTF-8");
	assert_str_equal(doc.version, "2.34");
	assert(doc.root.tag.len == 0);
	assert(doc.root.children.len() == 2);
	assert(doc.root.children[0].tag.len != 0);
	assert(doc.root.children[1].tag.len != 0);
	foreach(child : doc.root.children) {
		assert_str_equal(child.tag, "character");
	}
	XMLNode* current = doc.root.get_child(0);
	assert(current.children.len() == 2);
	assert(current.attributes.len() == 2);
	assert_has_attribute(current, "name", "kris");
	assert_has_attribute(current, "cash", "600");
	assert_tag(current.get_child(0), "attacks");
	assert(current.get_child(0).children.len() == 1);
	assert_tag(current.get_child(0).get_child(0), "swing");
	assert_has_attribute(current.get_child(0).get_child(0), "desc", "swing an equipped melee weapon at an opponent!");
	assert_has_attribute(current.get_child(0).get_child(0), "damage", "50");
	current = current.get_child(1);
	assert_tag(current, "inventory");
	assert_has_attribute(current, "capacity", "200");
	assert(current.children.len() == 4);
	foreach(child : current.children) assert(child.attributes.len() == 3);
	assert_has_attribute(current.get_child(0), "name","rope");
	assert_has_attribute(current.get_child(0), "value", "30");
	assert_has_attribute(current.get_child(0), "weight", "16");
	assert_has_attribute(current.get_child(1), "name","candle");
	assert_has_attribute(current.get_child(1), "value", "10");
	assert_has_attribute(current.get_child(1), "weight", "1");
	assert_has_attribute(current.get_child(2), "name","lighter");
	assert_has_attribute(current.get_child(2), "value", "5");
	assert_has_attribute(current.get_child(2), "weight", "0.5");
	assert_has_attribute(current.get_child(3), "name","sword");
	assert_has_attribute(current.get_child(3), "value", "200");
	assert_has_attribute(current.get_child(3), "weight", "36");

	current = doc.root.children[1];
	assert_has_attribute(current, "name", "suzie");
	assert_has_attribute(current, "cash", "10");
	current = current.get_child(0);
	assert_tag(current, "attacks");
	assert(current.children.len() == 1);
	current = current.get_child(0);
	assert_tag(current, "swing");
	assert(current.attributes.len() == 2);
	assert_has_attribute(current, "desc", "swing an equipped melee weapon at an opponent!");
	assert_has_attribute(current, "damage", "300");
	current = doc.root.get_child(1).get_child(1);
	assert_tag(current, "inventory");
	assert_has_attribute(current,  "capacity", "200");
	assert(current.children.len() == 3);
	foreach(child : current.children) assert(child.attributes.len() == 3);
	assert_has_attribute(current.get_child(0), "name","cigars");
	assert_has_attribute(current.get_child(0), "value", "500");
	assert_has_attribute(current.get_child(0), "weight", "0.5");
	assert_has_attribute(current.get_child(1), "name","lighter");
	assert_has_attribute(current.get_child(1), "value", "5");
	assert_has_attribute(current.get_child(1), "weight", "0.5");
	assert_has_attribute(current.get_child(2), "name","big hammer");
	assert_has_attribute(current.get_child(2), "value", "200");
	assert_has_attribute(current.get_child(2), "weight", "36");
	doc.free();
	assert(doc.root == null);
}

macro assert_tag(XMLNode* node, String a){
	assert_str_equal(node.tag, a);
}

macro assert_has_attribute(XMLNode* node, String a, String b){
	assert_str_equal(node.try_get_attribute(a), b);
}

macro assert_str_equal(String a, String b){
	assert(a.len == b.len);
	for(int i = 0; i < a.len ; i++){
		assert(a[i] == b[i], "String \"%s\" != \"%s\"", a, b);
	}
}