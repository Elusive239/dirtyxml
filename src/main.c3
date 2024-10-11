import std::io;
import xml;

const int NUM_OF_TESTS = 3;

fn void DString.append_node(DString* dstr, XMLNode* node, usz tabs = 1){
	if(node.tag.len() == 0 && node.children.len() > 0){
		for(int i =0; i < node.children.len(); i++){
			XMLNode* cnode = node.children[i];
			dstr.append_node(cnode, tabs);
		}
		return;
	}else if(node.tag.len() == 0){
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
	if(node.inner_text.len() > 0){
		int j;
		for(j; j < node.inner_text.len(); j++){
			char c = node.inner_text[j];
			if(c == ' ' || c == '\n' || c == '\t' || c == '\r'){
				break;
			}
		}
		if(j != node.inner_text.len()){
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

fn void! test(){
	@pool(){
		DString dstring = dstring::temp_new();
		for(int i = 1; i < NUM_OF_TESTS + 1; i++){
			io::printfn("[Test %d]", i);
			dstring.appendf("test%d", i);
			dstring.append(".xml");
			XMLDocument doc;
			int test = doc.load(dstring.tcopy_str());
			if(test != 0){
				io::printfn("Test %d failed!", i);
			}
			dstring.clear();
			dstring.append_node(doc.root);
			io::printf("%s", dstring);

			/*
				io::printfn("root: %s, %s", doc.root.tag, doc.root.inner_text);
				for(int y = 0; y < doc.root.attributes.len(); y++) {
					XMLAttribute attribute = *doc.root.attributes.get(y);
					io::printfn("%s: %s", attribute.key, attribute.value);
				}
				for(int y = 0; y < doc.root.children.len(); y++) {
					XMLNode child = *doc.root.children.get(y);
					io::printfn("%s -> %s, %s", doc.root.tag, child.tag, child.inner_text);
				}
			*/
			dstring.clear();
			doc.free(); //still needs to be called, have not implemented allocators!
			io::printfn("[End Test %d]", i);
		}
	};
}

fn void! main(String[] args)
{
	test()!;
	// return 0;
}
