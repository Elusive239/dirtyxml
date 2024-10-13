import std::io;
import xml;

fn void test(int i){
	XMLDocument doc;
	defer doc.free();
	DString dstr;
	dstr.append("test");
	dstr.appendf("%d.xml", i);
	doc.load(dstr.str_view());
	dstr.free();
	io::printfn("[TEST %d]", i);
	io::printf("%s", doc);
	io::printfn("[COMPLETE %d]", i);
}

fn int main(String[] args)
{
	for(int i = 1; i < 7; i++) test(i);
	return 0;
}
