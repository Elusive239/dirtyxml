import dxml;

fn void test_1() @test{
	XMLDocument doc;
	doc.load_file("resources/test1.xml")!!;
	assert(doc.root != null);
	assert(doc.root.children.len() == 2);
	assert_tag(doc.root.get_child(0), "root");
	@assert_str_equal(doc.root.get_child(0).inner_text, "I am root");
	assert_tag(doc.root.get_child(1), "other");
	@assert_str_equal(doc.root.get_child(1).inner_text, "I am not root");
	doc.free();
	assert(doc.root == null);
}

fn void test_2() @test{
	XMLDocument doc;
	doc.load_file("resources/test2.xml")!!;
	assert(doc.root != null);
	assert(doc.encoding.len == 0);
	assert(doc.version.len == 0);
	assert_tag(doc.root, "root");
	@assert_str_equal(doc.root.inner_text.trim(), "I am root"); //trim it because we can't have multiline strings
	assert(doc.root.children.len() == 2);
	assert(doc.root.attributes.len() == 0);
	assert_tag(doc.root.get_child(0), "inline");
	assert_tag(doc.root.get_child(1), "other");
	assert_has_attribute(doc.root.get_child(1), "key", "value");
	doc.free();
	assert(doc.root == null);
}

fn void test_3() @test{
	XMLDocument doc;
	doc.load_file("resources/test3.xml")!!;
	assert(doc.root != null);
	assert(doc.encoding.len == 0);
	assert(doc.version.len == 0);
	assert_tag(doc.root, "root");
	assert(doc.root.children.len() == 2);
	assert_tag(doc.root.get_child(0), "inner");
	assert(doc.root.get_child(0).children.len() == 1);
	assert_tag(doc.root.get_child(0).get_child(0), "more");
	@assert_str_equal(doc.root.get_child(0).get_child(0).inner_text, "Hi this is s'more text!");
	assert_tag(doc.root.get_child(1), "another");
	assert_has_attribute(doc.root.get_child(1), "key", "value");
	@assert_str_equal(doc.root.get_child(1).inner_text, "This is another node!");
	doc.free();
	assert(doc.root == null);
}

fn void test_4() @test{
	XMLDocument doc;
	doc.load_file("resources/test4.xml")!!;
	assert(doc.root != null);
	@assert_str_equal(doc.encoding, "UTF-8");
	@assert_str_equal(doc.version, "2.34");
	assert(doc.root.tag.len == 0);
	assert(doc.root.children.len() == 2);
	assert(doc.root.children[0].tag.len != 0);
	assert(doc.root.children[1].tag.len != 0);
	foreach(child : doc.root.children) {
		assert_tag(child, "character");
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
	@assert_str_equal(node.tag, a, "\"%s\" != tag \"%s\" in this node.");
}

macro assert_has_attribute(XMLNode* node, String a, String b){
	@assert_str_equal(node.try_get_attribute(a), b, "\"%s\" has no value \"%s\" in this node.");
}

macro @assert_str_equal(String a, String b, String $msg = "String \"%s\" != \"%s\""){
	assert(a.len == b.len, "\"%s\" and \"%s\" are different sizes, therefore not equal.", a, b);
	for(int i = 0; i < a.len ; i++){
		assert(a[i] == b[i],$msg, a, b);
	}
}