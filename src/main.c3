import std::io;
import xml;

fn void! test(int i){
	io::printfn("[TEST %d]", i);
	XMLDocument doc;
	defer doc.free();
	DString dstr;
	dstr.append("test");
	dstr.appendf("%d.xml", i);
	// doc.load_file(dstr.str_view())!!;
	File file = file::open(dstr.str_view(), "r")!;
	doc.load_from_stream(&file)!;
	file.close()!;
	dstr.free();
	io::printf("%s", doc);
	io::printfn("[COMPLETE %d]", i);
}



fn void main(String[] args)
{
	for(int i = 1; i < 7; i++) test(i)!!;
}
