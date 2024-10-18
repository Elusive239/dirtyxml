import std::io;
import dxml;

fn void! stream_example(){
	XMLDocument doc; defer doc.free();
	File file = file::open("resources/test4.xml", "rb")!;
	doc.load_from_stream(&file)!;
	file.close()!;

	// File file2 = file::open("outfile4.xml", "wb")!!;
	// defer file2.close()!;
	// doc.write_to_stream(&file2)!;

	io::printf("%s", doc);
}

fn void main(String[] args)
{
	if(args.len == 1){
		io::printfn("[USAGE] Pass in the name(s) or paths to any XML File(s) you wish to print to console!");
		return;
	}
	@pool(){
		foreach(filename : args[1..]){ //first arg is always name of executable i believe
			XMLDocument* doc = mem::temp_new(XMLDocument);
			doc.tload_file(filename)!!;
			io::printfn("%s", doc);
		}
	};
}

