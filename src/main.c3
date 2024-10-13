import std::io;
import xml;

const int NUM_OF_TESTS = 5;

fn void DString.append_node(DString* dstr, XMLNode* node, usz tabs = 1){
	if(node.tag.len == 0 && node.children.len() > 0){
		for(int i =0; i < node.children.len(); i++){
			XMLNode* cnode = node.children[i];
			dstr.append_node(cnode, tabs);
		}
		return;
	}else if(node.tag.len == 0){
		dstr.append("[ERROR] Tag has no length & no children.");
		return;
	}


	const char TAB = '\t';
	dstr.append_repeat(TAB, tabs-1);
	dstr.appendf("<%s", node.tag);
	//append attributes
	for(int i =0; i < node.attributes.len(); i++){
		XMLAttribute* attribute = node.attributes.get(i);
		dstr.appendf (" %s=\"%s\"", attribute.key, attribute.value);
		// &dstr.append_node(node.attributes.get(i), tabs + 1);
	}
	dstr.append_char('>');
	if(node.inner_text.len > 0){
		int j;
		for(j; j < node.inner_text.len; j++){
			char c = node.inner_text[j];
			if(c == ' ' || c == '\n' || c == '\t' || c == '\r'){
				break;
			}
		}
		if(j != node.inner_text.len){
			dstr.append_char('\n');
			dstr.append_repeat(TAB, tabs);
			dstr.appendf("%s", node.inner_text);
		}
	}
	//append children
	for(int i =0; i < node.children.len(); i++){
		XMLNode* cnode = node.children[i];
		dstr.append_node(cnode, tabs + 1);
	}
	dstr.append_char('\n');
	dstr.append_repeat(TAB, tabs-1);
	dstr.appendf("</%s>", node.tag);
	dstr.append_char('\n');
}

fn void test(int i = 1){
	@pool(){
		DString dstring = dstring::temp_new();
		io::printfn("[Test %d]", i);
		dstring.appendf("test%d", i);
		dstring.append(".xml");
		XMLDocument doc;
		int test = doc.load(dstring.tcopy_str());
		dstring.clear();
		if(test != 0){
			io::printfn("[Failed Test %d]", i);
			return;
		}
		dstring.append_node(doc.root);
		io::printfn("version=\"%s\" encoding=\"%s\"", doc.version , doc.encoding);
		io::printf("%s", dstring);
		dstring.clear();
		doc.free(); //still needs to be called, have not implemented allocators!
		io::printfn("[End Test %d]", i);
	};
}

fn int main(String[] args)
{
	test(1);
	test(2);
	test(3);
	test(4);
	test(5);
	test(6);
	return 0;
}
