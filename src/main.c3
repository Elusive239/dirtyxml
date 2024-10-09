import std::io;
import xml;

const int NUM_OF_TESTS = 3;

fn void test(){
	@pool(){
		DString dstring = dstring::temp_new();
		for(int i = 1; i < NUM_OF_TESTS; i++){
			io::printfn("[Test %d]", i);
			dstring.appendf("test%d", i);
			dstring.append(".xml");
			XMLDocument doc;
			doc.load(dstring.tcopy_str());

			io::printfn("root: %s", doc.root.inner_text);
    		io::printfn("root: %s", doc.root.tag);
			for(int y = 0; y < doc.root.attributes.len(); y++) {
				XMLAttribute attribute = *doc.root.attributes.get(y);
				io::printfn("%s: %s", attribute.key, attribute.value);
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
