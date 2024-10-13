module xml;
import std::io;
import std::collections;
import std::io::path;

struct XMLDocument
{
    XMLNode* root;
    String version;
    String encoding;
}

struct XMLAttribute
{
    String key;
    String value;
}

struct XMLNode
{
    String tag;
    String inner_text;
    XMLNode* parent;
    XMLAttributeList attributes;
    XMLNodeList children;
}

enum TagType : int (int value)
{
    TAG_START = 0,
    TAG_INLINE = 1,
    ERROR = 2,
}

//decided to use C3s built in lists!
def XMLAttributeList = List(<XMLAttribute*>);
def XMLNodeList = List(<XMLNode*>);

//Functions


fn void XMLDocument.free(&self){
    if(self.encoding.len > 0) free(self.encoding);
    if(self.version.len > 0) free(self.version);
    if(self.root != null) self.root.free();
}

fn void XMLNode.free(&self){
   
    self.attributes.free();
    self.children.free();
    if(self.tag.len > 0) free(self.tag);
    if(self.inner_text.len > 0) free(self.inner_text);
}

fn XMLNode* new_node(XMLNode* parent){
    XMLNode* node   = calloc(XMLNode.sizeof);
    node.parent     = parent;
    node.tag        = "";
    node.inner_text = "";
    node.attributes.new_init();
    node.children.new_init();
    if (parent != null) parent.children.push(node);
    return node;
}

fn String XMLNode.find_attribute(XMLNode* node, String key){
    for(int i =0; i < node.attributes.len(); i++){
        if(str_equal(key, node.attributes[i].key[0..(node.attributes[i].key.len-2)])) return node.attributes[i].value;
    }
    return "";
}

/*OPENING DOCUMENTS*/

fn int XMLDocument.load(XMLDocument* doc, String path){
    if(!file::is_file(path)){
        io::printfn("[INFO] File \"%s\" not found. Check your paths?", path);
        return 1;
    }
    char[] file = file::load_new(path)!!;

    doc.root = new_node(null);

    char[256] lex;
    int lexi = 0;
    int i = 0;

    for(i; file[i] != '<'; ++i); //skip to first node
    XMLNode* current = doc.root;
    while(i < file.len){
        if(file[i] == '<'){
            lex[lexi] = 0;
            //inner text
            if(lexi > 0){
                if(current == null){
                    io::printfn("[ERROR] Text outside of document.");
                    return 1;
                }

                current.inner_text = copy_zfa(&lex, lexi);
                lexi = 0;
            }
            
            //end of tag
            if(file[i+1] == '/'){
                i+=2;
                while(file[i] != '>'){
                    lex[lexi++] = file[i++];
                }
                lex[lexi] = 0;
                if(current == null){
                    io::printfn("[ERROR] Already at the root!" );
                    return 1;
                }
                if (compare_char_arr(current.tag, &lex, lexi)){
                    io::printfn("[ERROR] Mismatched tags (%s != %s)", current.tag, lex[0..lexi]);
                    return 1;
                }
                current = current.parent;
                i++;
                lexi = 0;
                continue;
            }

            //special nodes
            if(file[i+1] == '!' && file[i+2] == '-' && file[i+3] == '-'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = 0;

                if(!compare_char_arr("<!--", &lex, lexi)){
                    lex[lexi] = 0;
                    while(!(file[i-2] == '-' && file[i-1] == '-' && file[i] == '>')){
                        lex[lexi++] = file[i++];
                        lex[lexi] = 0;
                    }
                    continue;
                }
            }

            if(file[i+1] == '?'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = 0;
                if(!compare_char_arr("<?xml", &lex, lexi)){
                    lexi = 0;
                    XMLNode* desc = new_node(null);
                    if(parse_attributes(&lex, &lexi, file, &i, desc) == TagType.ERROR){
                        io::printfn("[ERROR] Failed to parse attributes.");
                        return 1;
                    }
                    doc.version = desc.find_attribute("version");
                    doc.encoding = desc.find_attribute("encoding");
                    desc.free();
                    continue;
                }
            }

            //set current node
            current = new_node(current);

            //start tag
            i++;
            TagType ret = parse_attributes(&lex, &lexi, file, &i, current);
            if(ret == TagType.TAG_INLINE){
                current = current.parent;
                i++;
                continue;
            }else if(ret == TagType.ERROR){
                io::printfn("[ERROR] Failed to parse attributes.");
                return 1;
            }
            
            lex[lexi] = 0;
            if( current.tag.len == 0){
                current.tag = copy_zfa(&lex, lexi);
            }
            lexi = 0;
            i++;
            continue;
        }
        else {
            lex[lexi++] = file[i++];
        }
    }
    return 0;
}

fn TagType parse_attributes(char[] lex, int* xlexi, char[] file, int* xi, XMLNode* current){
    int i = *xi;
    int lexi = *xlexi;
    XMLAttribute* current_attribute;
    while(file[i] != '>'){
        lex[lexi++] = file[i++];
        //tag name
        if(file[i] == ' ' && current.tag.len == 0){
            lex[lexi] = 0;
            current.tag = copy_zfa(lex, lexi);
            lexi = 0;
            i++;
            continue;
        }
        //ignore spaces (usually)
        if(lex[lexi-1] == ' '){
            lexi--;
            // continue;
        }
        //attribute key
        if(file[i] == '='){
            current_attribute = calloc(XMLAttribute.sizeof);
            lex[lexi] = 0;
            current_attribute.key = copy_zfa(lex, lexi);
            lexi = 0;
            continue;
        }
        //attribute value
        if(file[i] == '\"'){
            if(current_attribute.key.len == 0){
                io::printfn("[ERROR] Value has no key.");
                return TagType.ERROR;
            }
            lexi = 0;
            i++;
            while(file[i] != '\"'){
                lex[lexi++] = file[i++];
            }
            lex[lexi] = 0;
            current_attribute.value = copy_zfa(lex, lexi);
            current.attributes.push(current_attribute);
            current_attribute = null;
            lexi = 0;
            i++;
            continue;
        }
        if (file[i-1] == '/' && file[i] == '>'){
            lex[lexi] = 0;
            if(current.tag.len == 0){
                current.tag = copy_zfa(lex, lexi);
                i++;
            }
            lexi = 0;
            *xi = i;
            *xlexi = lexi;
            return TagType.TAG_INLINE;
        }
    }
    *xi = i;
    *xlexi = lexi;
    return TagType.TAG_START;
}

macro String copy_zfa(char[] arr, int len)  @private{
    String zstr = ((String)arr[0..len-1]).copy();
    return zstr;
}

macro bool compare_char_arr(String tag, char[] buffer, int len)  @private{
    len = len;
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}

macro bool str_equal(String a, String b) @private{
    // if(a.len != b.len) return false;
    for(int i = 0; i < b.len; i++){
        if(a[i] != b[i]) return false;
    }
    return true;
}

/*SAVING DOCUMENTS*/

fn int XMLDocument.write(XMLDocument* doc, String outpath){
    File! file = file::open(outpath, "w");
    defer file.close()!!;
    if(catch file){
        io::printfn("[ERROR] Couldn't create or open file %s!", outpath);
        return 1;
    }
    usz! res = file.write(doc.to_string());
    if(catch res){
        io::printfn("[ERROR] Failed to write to opened file %s!", outpath);
        return 1;
    }
    return 0;
}

fn String XMLDocument.to_string(XMLDocument* doc){
    if(doc.root == null){
        io::printfn("[ERROR] No document loaded!");
        return "";
    }

    DString dstr;
    if(doc.encoding.len > 0 || doc.version.len > 0) {
        String encoding = doc.encoding.len > 0 ? doc.encoding : "UTF-8";
        String version = doc.version.len > 0 ? doc.version : "1.0";
        dstr.appendfn( "<?xml version=\"%s\" encoding=\"%s\"?>", encoding, version);
    }
    //if no tag & the root has children, then there are multiple root nodes 
    //so we just skip to those instead of printing the empty one.
    if(doc.root.tag.len == 0 && doc.root.children.len() > 0){
		for(int i =0; i < doc.root.children.len(); i++){
			XMLNode* cnode = doc.root.children[i];
			append_node(&dstr, cnode);
		}
	}else {
        append_node(&dstr, doc.root);
    }
    return dstr.copy_str();
}

fn void append_node(DString* dstr, XMLNode* node, int tabs = 1){
    const char TAB = '\t';
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
    dstr.appendf("<%s", node.tag);
    append_tags(dstr, node);
    if(node.inner_text.len == 0 && node.children.len() == 0){ //inline nodes
        dstr.appendfn("/>");
        return;
    }
    String innerText = node.inner_text.trim(" \n\t\r\0");
    if(innerText.len > 0){
        for(int i =0; i < tabs; i++) dstr.append_char(TAB);
        dstr.appendfn(">\n%s", innerText);
    }else{
        dstr.appendfn(">");
    }
    for(int i =0; i < node.children.len(); i++) append_node(dstr, node.children[i], tabs + 1);
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
	dstr.appendfn("</%s>", node.tag);
}

macro void append_tags(DString* dstr, XMLNode* node){
    for(int i =0; i < node.attributes.len(); i++){
		XMLAttribute* attribute = node.attributes.get(i);
		dstr.appendf (" %s=\"%s\"", attribute.key, attribute.value);
	}
}

// fn void DString.append_node(DString* dstr, XMLNode* node, usz tabs = 1){
// 	if(node.tag.len == 0 && node.children.len() > 0){
// 		for(int i =0; i < node.children.len(); i++){
// 			XMLNode* cnode = node.children[i];
// 			dstr.append_node(cnode, tabs);
// 		}
// 		return;
// 	}else if(node.tag.len == 0){
// 		dstr.append("[ERROR] Tag has no length & no children.");
// 		return;
// 	}


// 	const char TAB = '\t';
// 	dstr.append_repeat(TAB, tabs-1);
// 	dstr.appendf("<%s", node.tag);
// 	//append attributes
// 	for(int i =0; i < node.attributes.len(); i++){
// 		XMLAttribute* attribute = node.attributes.get(i);
// 		dstr.appendf (" %s=\"%s\"", attribute.key, attribute.value);
// 		// &dstr.append_node(node.attributes.get(i), tabs + 1);
// 	}
// 	dstr.append_char('>');
// 	if(node.inner_text.len > 0){
// 		int j;
// 		for(j; j < node.inner_text.len; j++){
// 			char c = node.inner_text[j];
// 			if(c == ' ' || c == '\n' || c == '\t' || c == '\r'){
// 				break;
// 			}
// 		}
// 		if(j != node.inner_text.len){
// 			dstr.append_char('\n');
// 			dstr.append_repeat(TAB, tabs);
// 			dstr.appendf("%s", node.inner_text);
// 		}
// 	}
// 	//append children
// 	for(int i =0; i < node.children.len(); i++){
// 		XMLNode* cnode = node.children[i];
// 		dstr.append_node(cnode, tabs + 1);
// 	}
// 	dstr.append_char('\n');
// 	dstr.append_repeat(TAB, tabs-1);
// 	dstr.appendf("</%s>", node.tag);
// 	dstr.append_char('\n');
// }