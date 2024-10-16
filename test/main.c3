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
	for(int i = 1; i < 4; i++) test(i)!!;
}
