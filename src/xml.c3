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
            lex[lexi] = '\0';
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
                lex[lexi] = '\0';
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
                lex[lexi] = '\0';

                if(!compare_char_arr("<!--", &lex, lexi)){
                    lex[lexi] = '\0';
                    while(!(file[i-2] == '-' && file[i-1] == '-' && file[i] == '>')){
                        lex[lexi++] = file[i++];
                        lex[lexi] = '\0';
                    }
                    continue;
                }
            }

            if(file[i+1] == '?'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = '\0';
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
            
            lex[lexi] = '\0';
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
            lex[lexi] = '\0';
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
            lex[lexi] = '\0';
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
            lex[lexi] = '\0';
            current_attribute.value = copy_zfa(lex, lexi);
            current.attributes.push(current_attribute);
            current_attribute = null;
            lexi = 0;
            i++;
            continue;
        }
        if (file[i-1] == '/' && file[i] == '>'){
            lex[lexi] = '\0';
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

macro String copy_zfa(char[] arr, int len) {
    String zstr = ((String)arr[0..len]).copy();
    return zstr;
}

macro bool compare_char_arr(String tag, char[] buffer, int len){
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}

macro bool str_equal(String a, String b){
    // b = b[0..(b.len-2)];
    if(a.len != b.len) return false;
    for(int i = 0; i < a.len; i++){
        if(a[i] != b[i]) return false;
    }
    return true;
}
