import std::io;
import xml;

const int NUM_OF_TESTS = 3;

fn void test(){
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

			io::printfn("root: %s, %s", doc.root.tag, doc.root.inner_text);
			for(int y = 0; y < doc.root.attributes.len(); y++) {
				XMLAttribute attribute = *doc.root.attributes.get(y);
				io::printfn("%s: %s", attribute.key, attribute.value);
			}
			for(int y = 0; y < doc.root.children.len(); y++) {
				XMLNode child = *doc.root.children.get(y);
				io::printfn("%s -> %s, %s", doc.root.tag, child.tag, child.inner_text);
			}
			dstring.clear();
			doc.free(); //still needs to be called, have not implemented allocators!
			io::printfn("[End Test %d]", i);
		}
	};
}

fn int main(String[] args)
{
	test();
	return 0;
}
