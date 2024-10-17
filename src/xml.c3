module dxml;
import std::io;
import std::collections;
import std::io::path;

// Types

struct XMLDocument (Printable)
{
    XMLNode* root;
    String version;
    String encoding;
}

struct XMLAttribute (Printable)
{
    String key;
    String value;
}

struct XMLNode (Printable)
{
    String tag;
    String inner_text;
    XMLNode* parent;
    XMLAttributeList attributes;
    XMLNodeList children;
}

enum TagType
{
    TAG_START,
    TAG_INLINE,
}

fault XMLError{
    TAG_PARSING,
    TEXT_OUTSIDE_NODE,
    MISMATCHED_TAGS,
    CLOSING_UNOPENED_NODE,
    ATTRIBUTE_DOES_NOT_EXIST,
    CHILD_NODE_DOES_NOT_EXIST,
    COMMENT_NEVER_CLOSED,
}

// Decided to use C3s built in lists (for now!)
def XMLNodeList = List(<XMLNode*>);
def XMLAttributeList = List(<XMLAttribute*>);

//Free Memory

fn void XMLDocument.free(&self, Allocator allocator = allocator::heap()){
    if(self.encoding.len > 0) allocator::free(allocator, self.encoding);
    if(self.version.len > 0) allocator::free(allocator, self.version);
    if(self.root != null) self.root.free(allocator);
    self.root = null;
}

fn void XMLNode.free(&self, Allocator allocator = allocator::heap()){
    for(int i = 0; i < self.attributes.len(); i++) self.attributes[i].free(allocator);
    self.attributes.free();
    for(int i = 0; i < self.children.len(); i++) self.children[i].free();
    self.children.free();
    if(self.tag.len > 0) allocator::free(allocator, self.tag);
    if(self.inner_text.len > 0) allocator::free(allocator, self.inner_text);
    allocator::free(allocator, self);
}

fn void XMLAttribute.free(&self, Allocator allocator = allocator::heap()){
    if(self.key.len   != 0) allocator::free(allocator, self.key);
    if(self.value.len != 0) allocator::free(allocator, self.value);
    allocator::free(allocator, self);
}

// Helper Methods

fn XMLNode* new_node(XMLNode* parent, Allocator allocator = allocator::heap()){
    XMLNode* node   = (XMLNode*) allocator::calloc(allocator, XMLNode.sizeof);
    node.parent     = parent;
    node.tag        = "";
    node.inner_text = "";
    node.attributes.new_init(allocator: allocator);
    node.children.new_init(allocator: allocator);
    if (parent != null) parent.children.push(node);
    return node;
}

fn String! XMLNode.get_attribute(XMLNode* node, String key){
    for(int i =0; i < node.attributes.len(); i++){
        String other = node.attributes[i].key[0..(node.attributes[i].key.len-1)];
        if(!str_equal(other, key)) return node.attributes[i].value;
    }
    return XMLError.ATTRIBUTE_DOES_NOT_EXIST?;
}

fn String XMLNode.try_get_attribute(XMLNode* node, String key){
    String! str = node.get_attribute(key);
    if(try str){
        return str;
    }
    return "";
}

fn XMLNode*[] XMLNode.get_by_tag(XMLNode* node, String tag, Allocator allocator = allocator::heap()){
    XMLNodeList list;
    list.new_init(allocator: allocator);
    defer list.free();
    for(int i =0; i < node.children.len(); i++){
        String other = node.get_child(i).tag[0..(node.get_child(i).tag.len-1)];
        if(!str_equal(other, tag)) list.push(node.get_child(i));
    }
    return list.to_new_array(allocator: allocator);
}

fn XMLNode* XMLNode.get_child(XMLNode* node, int index){
    // if(index > node.children.len()) return XMLError.CHILD_NODE_DOES_NOT_EXIST?;
    return node.children[index];
}

// Load data to parse from [SOURCE] Methods

fn void! XMLDocument.load_from_stream(XMLDocument* doc, InStream stream, Allocator allocator = allocator::heap()){
    usz len = io::available(stream)! ;
    char[] buffer = allocator::alloc_array(allocator, char, len);
    io::read_all(stream, buffer)!;
    doc.load(buffer)!;
    allocator::free(allocator, buffer);
}

fn void! XMLDocument.load_from_path(XMLDocument* doc, Path path, Allocator allocator = allocator::heap()){
    doc.load_file(path.str_view(), allocator)!;
}

fn void! XMLDocument.load_file(XMLDocument* doc, String path, Allocator allocator = allocator::heap()){
    char[] file = file::load_new(path, allocator)!;
    doc.load(file)!;
    allocator::free(allocator, file);
}


fn void! XMLDocument.load(XMLDocument* doc, char[] file, Allocator allocator = allocator::heap()){
    doc.root = new_node(null, allocator);

    char[256] lex;
    int lexi = 0;
    int i = 0;

    for(i; i < file.len && file[i] != '<'; ++i); //skip to first node
    if(file[i+1] == '?'){                        //handle ?xml special node (the prolog)
        while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
        lex[lexi] = 0;
        if(!compare_buffer("<?xml", &lex, lexi)){
            lexi = 0;
            XMLNode* desc = new_node(null, allocator);
            desc.tag = ("?xml").copy(allocator);
            parse_attributes(&lex, &lexi, file, &i, desc, allocator)!;
            doc.version = desc.try_get_attribute("version").copy(allocator);
            doc.encoding = desc.try_get_attribute("encoding").copy(allocator);
            desc.free();
        }
    }
    XMLNode* current = doc.root;
    while(i < file.len){
        if(file[i] == '<'){
            lex[lexi] = 0;
            //inner text
            if(lexi > 0){
                if(current == null){
                    io::eprintfn("[ERROR] Text outside of document.");
                    return XMLError.TEXT_OUTSIDE_NODE?;
                }
                if(current.inner_text.len == 0){
                    current.inner_text = copy_buffer(&lex, lexi, allocator);
                }

                // current.inner_text = copy_buffer(&lex, lexi, allocator);
                // io::printfn("WE GOT SOME TEXT: %s", current.inner_text);
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
                    io::eprintfn("[ERROR] Already at the root!" );
                    return XMLError.CLOSING_UNOPENED_NODE?;
                }
                if (compare_buffer(current.tag, &lex, lexi)){
                    io::eprintfn("[ERROR] Mismatched tags (%s != %s)", current.tag, lex[0..lexi]);
                    return XMLError.MISMATCHED_TAGS?;
                }
                current = current.parent;
                i++;
                lexi = 0;
                continue;
            }

            //comments
            if(handle_comment(&lex, &lexi, file, &i)!){
                continue;
            }

            //set current node
            current = new_node(current, allocator);

            //start tag
            i++;
            if( parse_attributes(&lex, &lexi, file, &i, current, allocator)! == TagType.TAG_INLINE){
                current = current.parent;
                i++;
                continue;
            }
            
            lex[lexi] = 0;
            if( current.tag.len == 0){
                current.tag = copy_buffer(&lex, lexi, allocator);
            }
            lexi = 0;
            i++;
            continue;
        }
        else {
            lex[lexi++] = file[i++];
        }
    }

    if(doc.root.tag.len == 0 && doc.root.children.len() == 1 && doc.root.attributes.len() == 0){
        current = doc.root;
        doc.root = current.children[0];
        current.children.pop()!!;
        current.free(allocator);
    }
}

//temporary allocator assumed

fn void! XMLDocument.tload_from_path(XMLDocument* doc, Path path){
    doc.load_from_path(path, allocator::temp())!;
}

fn void! XMLDocument.tload_file(XMLDocument* doc, String path){
    doc.load_file(path, allocator::temp())!;
}

fn void! XMLDocument.tload(XMLDocument* doc, char[] file){
    doc.load(file, allocator::temp())!;
}

fn bool! handle_comment(char[] lex, int* xlexi, char[] file, int* xi){
    //comments
    int i = *xi;
    int lexi = *xlexi;
    if(!(file[i+1] == '!' && file[i+2] == '-' && file[i+3] == '-')) return false;
    while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
    lex[lexi] = 0;
    if(!compare_buffer("<!--", lex, lexi)){
        lex[lexi] = 0;
        while(i < file.len && !(file[i-2] == '-' && file[i-1] == '-' && file[i] == '>')){
            lex[lexi++] = file[i++];
            lex[lexi] = 0;
        }
        *xi = i;
        *xlexi = lexi;
        return true;
    }
    *xi = i;
    *xlexi = lexi;
    return XMLError.COMMENT_NEVER_CLOSED?; //probably shouldn'y get here...
}

fn TagType! parse_attributes(char[] lex, int* xlexi, char[] file, int* xi, XMLNode* current, Allocator allocator = allocator::heap()){
    int i = *xi;
    int lexi = *xlexi;
    XMLAttribute* current_attribute = null;
    while(file[i] == ' ') i++; //skip any leading spaces

    while(file[i] != '>'){
        lex[lexi++] = file[i++];
        //tag name
        if(file[i] == ' ' && current.tag.len == 0){
            lex[lexi] = 0;
            current.tag = copy_buffer(lex, lexi, allocator);
            lexi = 0;
            i++;
            continue;
        }
        //ignore spaces (usually)
        if(lex[lexi-1] == ' '){
            lexi--;
        }
        //attribute key
        if(file[i] == '='){
            if(current_attribute == null){
                current_attribute = (XMLAttribute*) allocator::calloc(allocator, XMLAttribute.sizeof);
            }
            lex[lexi] = 0;
            current_attribute.key = copy_buffer(lex, lexi, allocator);
            lexi = 0;
            continue;
        }
        //attribute value
        if(file[i] == '\"'){
            if(current_attribute == null){
                io::eprintfn("[ERROR] current_attribute is null in attribute parsing.");
                return XMLError.TAG_PARSING?;
            }
            else if(current_attribute.key.len == 0){
                io::eprintfn("[ERROR] Attribute value has no key.");
                return XMLError.TAG_PARSING?;
            }
            lexi = 0;
            i++;
            while(file[i] != '\"'){
                lex[lexi++] = file[i++];
            }
            lex[lexi] = 0;
            current_attribute.value = copy_buffer(lex, lexi, allocator);
            current.attributes.push(current_attribute);
            current_attribute = null;
            lexi = 0;
            i++;
            continue;
        }
        if (file[i-1] == '/' && file[i] == '>'){
            lex[lexi] = 0;
            if(current.tag.len == 0){
                //lexi -1 because '/'
                current.tag = copy_buffer(lex, lexi-1, allocator);
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

// Save parsed data to [SOURCE] Methods

fn void! XMLDocument.write_to_stream(XMLDocument* doc, OutStream stream, Allocator allocator = allocator::heap()){
    String str = doc.to_string(allocator);
    io::write_all(stream, str)!;
    str.free();
}

fn void! XMLDocument.write_to_file(XMLDocument* doc, String path, Allocator allocator = allocator::heap()){
    String str = doc.to_string(allocator);
    File file = file::open(path, "w")!;
    file.write(str)!;
    file.close()!;
    str.free();
}

fn void! XMLDocument.write_to_path(XMLDocument* doc, Path path, Allocator allocator = allocator::heap()){
    doc.write_to_file(path.str_view(), allocator)!;
}

// Printable interface implementations

fn String XMLDocument.to_string(XMLDocument* doc, Allocator allocator = allocator::heap()) @dynamic{
    if(doc.root == null){
        io::eprintfn("[ERROR] No document loaded!");
        return "";
    }

    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    if(doc.encoding.len > 0 || doc.version.len > 0) {
        //doing copies because they may be freed later..
        String encoding = (doc.encoding.len > 0 ? doc.encoding : "UTF-8").copy(allocator);
        String version = (doc.version.len > 0 ? doc.version : "1.0").copy(allocator);
        dstr.appendfn( "<?xml version=\"%s\" encoding=\"%s\"?>", version, encoding);
    }
    //if no tag & the root has children, then there are multiple root nodes 
    //so we just skip to those instead of printing the empty one.
    // io::printfn("[%s]", doc.root.inner_text);
    if(doc.root.tag.len == 0 && doc.root.children.len() > 0){
		for(int i =0; i < doc.root.children.len(); i++){
			XMLNode* cnode = doc.root.children[i];
			dstr.append_node(cnode);
		}
	}else {
        dstr.append_node(doc.root);
    }
    return dstr.copy_str(allocator);
}

fn String XMLNode.to_string(XMLNode* node, Allocator allocator = allocator::heap()) @dynamic{
    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    dstr.append_node(node);
    return dstr.copy_str(allocator);
}

fn String XMLAttribute.to_string(XMLAttribute* attribute, Allocator allocator = allocator::heap()) @dynamic{
    DString dstr = dstring::new_with_capacity(100, allocator);
    defer dstr.free();
    dstr.appendf("%s=\"%s\"", attribute.key, attribute.value);
    return dstr.copy_str();
}

fn void DString.append_node(DString* dstr, XMLNode* node, int tabs = 1){
    const char TAB = '\t';
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
    dstr.appendf("<%s", node.tag);
    dstr.append_tags(node);
    if(node.inner_text.len == 0 && node.children.len() == 0){ //inline nodes
        dstr.appendfn("/>");
        return;
    }
    dstr.append_inner_text(node, tabs);
    for(int i =0; i < node.children.len(); i++) dstr.append_node(node.children[i], tabs + 1);
    for(int i =0; i < tabs - 1; i++) dstr.append_char(TAB);
	dstr.appendfn("</%s>", node.tag);
}

macro void DString.append_tags(DString* dstr, XMLNode* node){
    for(int i =0; i < node.attributes.len(); i++){
		XMLAttribute* attribute = node.attributes.get(i);
		dstr.appendf (" %s", attribute);
	}
}

macro void DString.append_inner_text(DString* dstr, XMLNode* node, int tabs){
    const char TAB = '\t';
    String innerText = node.inner_text;//.trim(" \n\t\r\0");
    if(innerText.len > 0){
        dstr.appendfn(">");
        for(int i =0; i < tabs; i++) dstr.append_char(TAB);
        dstr.appendf("%s\n", innerText);
    }else{
        dstr.appendfn(">");
    }
}

module dxml @private;

// Helper Macros

macro String copy_buffer(char[] buffer, int len, Allocator allocator = allocator::heap()){
    String zstr = ((String)buffer[0..len-1]).copy(allocator);
    return zstr;
}

macro bool compare_buffer(String tag, char[] buffer, int len){
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}

macro bool str_equal(String a, String b){
    for(int i = 0; i < b.len; i++){
        if(a[i] != b[i]) return true;
    }
    return false;
}