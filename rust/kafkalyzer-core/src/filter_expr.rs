use std::collections::HashMap;
use std::fmt;

use chrono::DateTime;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::json_path::FieldPath;

pub const MAX_EXPRESSION_LEN: usize = 65_536;
pub const MAX_AST_DEPTH: usize = 64;
pub const MAX_CONDITIONS: usize = 64;
pub const MAX_IN_LIST_ITEMS: usize = 256;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FilterError {
    pub message: String,
    pub start: usize,
    pub end: usize,
}

impl FilterError {
    pub fn new(message: impl Into<String>, start: usize, end: usize) -> Self {
        Self {
            message: message.into(),
            start,
            end,
        }
    }

    /// Converts byte offsets `[start, end)` into UTF-16 code unit offsets for Dart/UI highlighting.
    pub fn span_utf16(&self, input: &str) -> (usize, usize) {
        let start = byte_to_utf16_offset(input, self.start);
        let end = byte_to_utf16_offset(input, self.end);
        (start, end)
    }
}

impl fmt::Display for FilterError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} (at {}..{})", self.message, self.start, self.end)
    }
}

impl std::error::Error for FilterError {}

fn byte_to_utf16_offset(s: &str, byte_idx: usize) -> usize {
    let clamped = byte_idx.min(s.len());
    let mut safe_idx = clamped;
    while safe_idx > 0 && !s.is_char_boundary(safe_idx) {
        safe_idx -= 1;
    }
    s[..safe_idx].encode_utf16().count()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum FieldRef {
    Value(String),
    Key,
    KeyPath(String),
    Header(String),
    Timestamp,
    Offset,
    Partition,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CompOp {
    Eq,
    Ne,
    Gt,
    Ge,
    Lt,
    Le,
    Contains,
    StartsWith,
    EndsWith,
    Matches,
    In,
    Exists,
    IsNull,
    IsNotNull,
}

impl CompOp {
    pub fn is_unary(self) -> bool {
        matches!(self, Self::Exists | Self::IsNull | Self::IsNotNull)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Literal {
    String(String),
    Int(i64),
    Float(f64),
    Bool(bool),
    Null,
    List(Vec<Literal>),
    Placeholder(String),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FilterCondition {
    pub field: FieldRef,
    pub op: CompOp,
    pub value: Option<Literal>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum FilterNode {
    And(Vec<FilterNode>),
    Or(Vec<FilterNode>),
    Not(Box<FilterNode>),
    Cond(FilterCondition),
}

// ============================================================================
// Lexer
// ============================================================================

#[derive(Debug, Clone, PartialEq)]
enum TokenKind {
    LParen,
    RParen,
    LBracket,
    RBracket,
    Comma,
    Eq,
    Ne,
    Gt,
    Ge,
    Lt,
    Le,
    String(String),
    Int(i64),
    Float(f64),
    Placeholder(String),
    Ident(String),
}

#[derive(Debug, Clone)]
struct Token {
    kind: TokenKind,
    start: usize,
    end: usize,
}

fn is_ident_continue(b: u8) -> bool {
    b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-' | b'.' | b'$' | b'/' | b'~')
}

fn tokenize(input: &str) -> Result<Vec<Token>, FilterError> {
    let bytes = input.as_bytes();
    let mut tokens = Vec::new();
    let mut i = 0;

    while i < bytes.len() {
        let b = bytes[i];
        if b.is_ascii_whitespace() {
            i += 1;
            continue;
        }

        match b {
            b'(' => {
                tokens.push(Token {
                    kind: TokenKind::LParen,
                    start: i,
                    end: i + 1,
                });
                i += 1;
            }
            b')' => {
                tokens.push(Token {
                    kind: TokenKind::RParen,
                    start: i,
                    end: i + 1,
                });
                i += 1;
            }
            b'[' => {
                tokens.push(Token {
                    kind: TokenKind::LBracket,
                    start: i,
                    end: i + 1,
                });
                i += 1;
            }
            b']' => {
                tokens.push(Token {
                    kind: TokenKind::RBracket,
                    start: i,
                    end: i + 1,
                });
                i += 1;
            }
            b',' => {
                tokens.push(Token {
                    kind: TokenKind::Comma,
                    start: i,
                    end: i + 1,
                });
                i += 1;
            }
            b'=' => {
                let start = i;
                if i + 1 < bytes.len() && bytes[i + 1] == b'=' {
                    i += 2;
                } else {
                    i += 1;
                }
                tokens.push(Token {
                    kind: TokenKind::Eq,
                    start,
                    end: i,
                });
            }
            b'!' => {
                if i + 1 < bytes.len() && bytes[i + 1] == b'=' {
                    tokens.push(Token {
                        kind: TokenKind::Ne,
                        start: i,
                        end: i + 2,
                    });
                    i += 2;
                } else {
                    return Err(FilterError::new(
                        "Unexpected '!' (use '!=' or 'NOT')",
                        i,
                        i + 1,
                    ));
                }
            }
            b'>' => {
                let start = i;
                if i + 1 < bytes.len() && bytes[i + 1] == b'=' {
                    i += 2;
                    tokens.push(Token {
                        kind: TokenKind::Ge,
                        start,
                        end: i,
                    });
                } else {
                    i += 1;
                    tokens.push(Token {
                        kind: TokenKind::Gt,
                        start,
                        end: i,
                    });
                }
            }
            b'<' => {
                let start = i;
                if i + 1 < bytes.len() && bytes[i + 1] == b'=' {
                    i += 2;
                    tokens.push(Token {
                        kind: TokenKind::Le,
                        start,
                        end: i,
                    });
                } else {
                    i += 1;
                    tokens.push(Token {
                        kind: TokenKind::Lt,
                        start,
                        end: i,
                    });
                }
            }
            b'"' | b'\'' => {
                let quote = b;
                let start = i;
                i += 1;
                let mut out = String::new();
                let mut closed = false;
                while i < bytes.len() {
                    let c = bytes[i];
                    if c == b'\\' {
                        i += 1;
                        if i >= bytes.len() {
                            return Err(FilterError::new("Unterminated escape sequence", start, i));
                        }
                        let esc = bytes[i];
                        match esc {
                            b'n' => out.push('\n'),
                            b'r' => out.push('\r'),
                            b't' => out.push('\t'),
                            b'\\' => out.push('\\'),
                            b'"' => out.push('"'),
                            b'\'' => out.push('\''),
                            other => {
                                out.push('\\');
                                out.push(other as char);
                            }
                        }
                        i += 1;
                    } else if c == quote {
                        i += 1;
                        closed = true;
                        break;
                    } else {
                        let ch = input[i..].chars().next().unwrap();
                        out.push(ch);
                        i += ch.len_utf8();
                    }
                }
                if !closed {
                    return Err(FilterError::new("Unterminated string literal", start, i));
                }
                tokens.push(Token {
                    kind: TokenKind::String(out),
                    start,
                    end: i,
                });
            }
            b'{' if i + 1 < bytes.len() && bytes[i + 1] == b'{' => {
                let start = i;
                i += 2;
                let name_start = i;
                while i + 1 < bytes.len() && !(bytes[i] == b'}' && bytes[i + 1] == b'}') {
                    i += 1;
                }
                if i + 1 >= bytes.len() {
                    return Err(FilterError::new(
                        "Unterminated placeholder '{{...}}'",
                        start,
                        bytes.len(),
                    ));
                }
                let name = input[name_start..i].trim().to_string();
                i += 2;
                if name.is_empty() {
                    return Err(FilterError::new("Empty placeholder '{{}}'", start, i));
                }
                tokens.push(Token {
                    kind: TokenKind::Placeholder(name),
                    start,
                    end: i,
                });
            }
            b'-' | b'0'..=b'9' => {
                let start = i;
                if bytes[i] == b'-' {
                    if i + 1 >= bytes.len() || !bytes[i + 1].is_ascii_digit() {
                        return Err(FilterError::new("Unexpected '-'", start, i + 1));
                    }
                    i += 1;
                }
                while i < bytes.len() && bytes[i].is_ascii_digit() {
                    i += 1;
                }
                let mut is_float = false;
                if i < bytes.len()
                    && bytes[i] == b'.'
                    && i + 1 < bytes.len()
                    && bytes[i + 1].is_ascii_digit()
                {
                    is_float = true;
                    i += 1;
                    while i < bytes.len() && bytes[i].is_ascii_digit() {
                        i += 1;
                    }
                }
                if i < bytes.len() && (bytes[i] == b'e' || bytes[i] == b'E') {
                    is_float = true;
                    i += 1;
                    if i < bytes.len() && (bytes[i] == b'+' || bytes[i] == b'-') {
                        i += 1;
                    }
                    if i >= bytes.len() || !bytes[i].is_ascii_digit() {
                        return Err(FilterError::new("Invalid exponent in number", start, i));
                    }
                    while i < bytes.len() && bytes[i].is_ascii_digit() {
                        i += 1;
                    }
                }
                let slice = &input[start..i];
                if is_float {
                    let val: f64 = slice
                        .parse()
                        .map_err(|_| FilterError::new("Invalid float literal", start, i))?;
                    tokens.push(Token {
                        kind: TokenKind::Float(val),
                        start,
                        end: i,
                    });
                } else {
                    let val: i64 = slice
                        .parse()
                        .map_err(|_| FilterError::new("Invalid integer literal", start, i))?;
                    tokens.push(Token {
                        kind: TokenKind::Int(val),
                        start,
                        end: i,
                    });
                }
            }
            _ if b.is_ascii_alphabetic() || b == b'_' || b == b'$' => {
                let start = i;
                while i < bytes.len() {
                    let c = bytes[i];
                    if c == b'\\' && i + 1 < bytes.len() {
                        i += 2;
                    } else if c == b'[' {
                        // Allow bracketed path segments like value.items[0].name or value.a["b"]
                        i += 1;
                        let mut quote: Option<u8> = None;
                        while i < bytes.len() {
                            let bc = bytes[i];
                            if let Some(q) = quote {
                                if bc == b'\\' && i + 1 < bytes.len() {
                                    i += 2;
                                    continue;
                                }
                                if bc == q {
                                    quote = None;
                                }
                                i += 1;
                            } else if bc == b'"' || bc == b'\'' {
                                quote = Some(bc);
                                i += 1;
                            } else if bc == b']' {
                                i += 1;
                                break;
                            } else {
                                i += 1;
                            }
                        }
                    } else if c == b'.'
                        && i + 1 < bytes.len()
                        && (bytes[i + 1] == b'"' || bytes[i + 1] == b'\'')
                    {
                        // Quoted segment after dot: value."a.b"
                        i += 1;
                        let q = bytes[i];
                        i += 1;
                        while i < bytes.len() {
                            if bytes[i] == b'\\' && i + 1 < bytes.len() {
                                i += 2;
                            } else if bytes[i] == q {
                                i += 1;
                                break;
                            } else {
                                i += 1;
                            }
                        }
                    } else if is_ident_continue(c) {
                        i += 1;
                    } else {
                        break;
                    }
                }
                tokens.push(Token {
                    kind: TokenKind::Ident(input[start..i].to_string()),
                    start,
                    end: i,
                });
            }
            _ => {
                let ch = input[i..].chars().next().unwrap();
                return Err(FilterError::new(
                    format!("Unexpected character '{}'", ch),
                    i,
                    i + ch.len_utf8(),
                ));
            }
        }
    }

    Ok(tokens)
}

// ============================================================================
// Parser
// ============================================================================

struct Parser<'a> {
    input: &'a str,
    tokens: Vec<Token>,
    pos: usize,
    cond_count: usize,
}

impl<'a> Parser<'a> {
    fn new(input: &'a str, tokens: Vec<Token>) -> Self {
        Self {
            input,
            tokens,
            pos: 0,
            cond_count: 0,
        }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn next(&mut self) -> Option<Token> {
        if self.pos < self.tokens.len() {
            let tok = self.tokens[self.pos].clone();
            self.pos += 1;
            Some(tok)
        } else {
            None
        }
    }

    fn eof_pos(&self) -> usize {
        self.input.len()
    }

    fn peek_keyword(&self, kw: &str) -> bool {
        matches!(
            self.peek(),
            Some(Token {
                kind: TokenKind::Ident(s),
                ..
            }) if s.eq_ignore_ascii_case(kw)
        )
    }

    fn parse_or(&mut self, depth: usize) -> Result<FilterNode, FilterError> {
        if depth > MAX_AST_DEPTH {
            let pos = self
                .peek()
                .map(|t| t.start)
                .unwrap_or_else(|| self.eof_pos());
            return Err(FilterError::new(
                format!("Expression exceeds maximum nesting depth of {MAX_AST_DEPTH}"),
                pos,
                pos,
            ));
        }

        let mut children = Vec::new();
        let first = self.parse_and(depth)?;
        push_flattened_or(&mut children, first);

        while self.peek_keyword("OR") {
            self.next();
            let rhs = self.parse_and(depth)?;
            push_flattened_or(&mut children, rhs);
        }

        if children.len() == 1 {
            Ok(children.pop().unwrap())
        } else {
            Ok(FilterNode::Or(children))
        }
    }

    fn parse_and(&mut self, depth: usize) -> Result<FilterNode, FilterError> {
        let mut children = Vec::new();
        let first = self.parse_not(depth)?;
        push_flattened_and(&mut children, first);

        while self.peek_keyword("AND") {
            self.next();
            let rhs = self.parse_not(depth)?;
            push_flattened_and(&mut children, rhs);
        }

        if children.len() == 1 {
            Ok(children.pop().unwrap())
        } else {
            Ok(FilterNode::And(children))
        }
    }

    fn parse_not(&mut self, depth: usize) -> Result<FilterNode, FilterError> {
        if self.peek_keyword("NOT") {
            let tok = self.next().unwrap();
            if depth + 1 > MAX_AST_DEPTH {
                return Err(FilterError::new(
                    format!("Expression exceeds maximum nesting depth of {MAX_AST_DEPTH}"),
                    tok.start,
                    tok.end,
                ));
            }
            let inner = self.parse_not(depth + 1)?;
            return Ok(FilterNode::Not(Box::new(inner)));
        }
        self.parse_primary(depth)
    }

    fn parse_primary(&mut self, depth: usize) -> Result<FilterNode, FilterError> {
        let Some(tok) = self.peek().cloned() else {
            let pos = self.eof_pos();
            return Err(FilterError::new(
                "Unexpected end of expression; expected a condition or '('",
                pos,
                pos,
            ));
        };

        if matches!(tok.kind, TokenKind::LParen) {
            self.next();
            if depth + 1 > MAX_AST_DEPTH {
                return Err(FilterError::new(
                    format!("Expression exceeds maximum nesting depth of {MAX_AST_DEPTH}"),
                    tok.start,
                    tok.end,
                ));
            }
            let inner = self.parse_or(depth + 1)?;
            match self.next() {
                Some(Token {
                    kind: TokenKind::RParen,
                    ..
                }) => Ok(inner),
                Some(other) => Err(FilterError::new(
                    "Expected closing ')'",
                    other.start,
                    other.end,
                )),
                None => Err(FilterError::new(
                    "Expected closing ')'",
                    self.eof_pos(),
                    self.eof_pos(),
                )),
            }
        } else {
            self.parse_condition()
        }
    }

    fn parse_condition(&mut self) -> Result<FilterNode, FilterError> {
        self.cond_count += 1;
        if self.cond_count > MAX_CONDITIONS {
            let pos = self
                .peek()
                .map(|t| t.start)
                .unwrap_or_else(|| self.eof_pos());
            return Err(FilterError::new(
                format!("Expression exceeds maximum of {MAX_CONDITIONS} conditions"),
                pos,
                pos,
            ));
        }

        let field_tok = self.next().ok_or_else(|| {
            FilterError::new("Expected field name", self.eof_pos(), self.eof_pos())
        })?;

        let field = match &field_tok.kind {
            TokenKind::Ident(raw) => parse_field_ref(raw, field_tok.start, field_tok.end)?,
            _ => {
                return Err(FilterError::new(
                    "Expected field reference (e.g. value.id, key, header.type, timestamp, offset, partition)",
                    field_tok.start,
                    field_tok.end,
                ));
            }
        };

        let op_tok = self.next().ok_or_else(|| {
            FilterError::new(
                "Expected operator after field",
                self.eof_pos(),
                self.eof_pos(),
            )
        })?;

        let op = match &op_tok.kind {
            TokenKind::Eq => CompOp::Eq,
            TokenKind::Ne => CompOp::Ne,
            TokenKind::Gt => CompOp::Gt,
            TokenKind::Ge => CompOp::Ge,
            TokenKind::Lt => CompOp::Lt,
            TokenKind::Le => CompOp::Le,
            TokenKind::Ident(s) => {
                if s.eq_ignore_ascii_case("contains") {
                    CompOp::Contains
                } else if s.eq_ignore_ascii_case("startswith") {
                    CompOp::StartsWith
                } else if s.eq_ignore_ascii_case("endswith") {
                    CompOp::EndsWith
                } else if s.eq_ignore_ascii_case("matches") {
                    CompOp::Matches
                } else if s.eq_ignore_ascii_case("in") {
                    CompOp::In
                } else if s.eq_ignore_ascii_case("exists") {
                    CompOp::Exists
                } else if s.eq_ignore_ascii_case("is") {
                    if self.peek_keyword("NOT") {
                        self.next();
                        if self.peek_keyword("NULL") {
                            self.next();
                            CompOp::IsNotNull
                        } else {
                            let pos = self
                                .peek()
                                .map(|t| (t.start, t.end))
                                .unwrap_or((op_tok.start, op_tok.end));
                            return Err(FilterError::new(
                                "Expected 'NULL' after 'IS NOT'",
                                pos.0,
                                pos.1,
                            ));
                        }
                    } else if self.peek_keyword("NULL") {
                        self.next();
                        CompOp::IsNull
                    } else {
                        let pos = self
                            .peek()
                            .map(|t| (t.start, t.end))
                            .unwrap_or((op_tok.start, op_tok.end));
                        return Err(FilterError::new(
                            "Expected 'NULL' or 'NOT NULL' after 'IS'",
                            pos.0,
                            pos.1,
                        ));
                    }
                } else {
                    return Err(FilterError::new(
                        format!("Unknown operator '{s}'"),
                        op_tok.start,
                        op_tok.end,
                    ));
                }
            }
            _ => {
                return Err(FilterError::new(
                    "Expected comparison operator",
                    op_tok.start,
                    op_tok.end,
                ));
            }
        };

        if op.is_unary() {
            return Ok(FilterNode::Cond(FilterCondition {
                field,
                op,
                value: None,
            }));
        }

        let (lit, lit_start, lit_end) = self.parse_literal()?;

        if op == CompOp::In {
            match &lit {
                Literal::List(_) | Literal::Placeholder(_) => {}
                _ => {
                    return Err(FilterError::new(
                        "Operator 'in' requires a list literal '[...]' or placeholder '{{...}}'",
                        lit_start,
                        lit_end,
                    ));
                }
            }
        } else if matches!(lit, Literal::List(_)) {
            return Err(FilterError::new(
                "List literals '[...]' are only valid with the 'in' operator",
                lit_start,
                lit_end,
            ));
        }

        if matches!(
            op,
            CompOp::Contains | CompOp::StartsWith | CompOp::EndsWith | CompOp::Matches
        ) && !matches!(lit, Literal::String(_) | Literal::Placeholder(_))
        {
            return Err(FilterError::new(
                "String/regex operator requires a string literal or placeholder",
                lit_start,
                lit_end,
            ));
        }

        Ok(FilterNode::Cond(FilterCondition {
            field,
            op,
            value: Some(lit),
        }))
    }

    fn parse_literal(&mut self) -> Result<(Literal, usize, usize), FilterError> {
        let tok = self.next().ok_or_else(|| {
            FilterError::new("Expected literal value", self.eof_pos(), self.eof_pos())
        })?;

        match tok.kind {
            TokenKind::String(s) => Ok((Literal::String(s), tok.start, tok.end)),
            TokenKind::Int(n) => Ok((Literal::Int(n), tok.start, tok.end)),
            TokenKind::Float(f) => Ok((Literal::Float(f), tok.start, tok.end)),
            TokenKind::Placeholder(p) => Ok((Literal::Placeholder(p), tok.start, tok.end)),
            TokenKind::Ident(ref s) if s.eq_ignore_ascii_case("true") => {
                Ok((Literal::Bool(true), tok.start, tok.end))
            }
            TokenKind::Ident(ref s) if s.eq_ignore_ascii_case("false") => {
                Ok((Literal::Bool(false), tok.start, tok.end))
            }
            TokenKind::Ident(ref s) if s.eq_ignore_ascii_case("null") => {
                Ok((Literal::Null, tok.start, tok.end))
            }
            TokenKind::LBracket => {
                let mut items = Vec::new();
                if matches!(
                    self.peek(),
                    Some(Token {
                        kind: TokenKind::RBracket,
                        ..
                    })
                ) {
                    let end_tok = self.next().unwrap();
                    return Ok((Literal::List(items), tok.start, end_tok.end));
                }
                loop {
                    let (item, item_start, item_end) = self.parse_literal()?;
                    if matches!(item, Literal::List(_)) {
                        return Err(FilterError::new(
                            "Nested lists are not allowed",
                            item_start,
                            item_end,
                        ));
                    }
                    items.push(item);
                    if items.len() > MAX_IN_LIST_ITEMS {
                        return Err(FilterError::new(
                            format!("'in' list exceeds maximum of {MAX_IN_LIST_ITEMS} items"),
                            item_start,
                            item_end,
                        ));
                    }
                    match self.next() {
                        Some(Token {
                            kind: TokenKind::Comma,
                            ..
                        }) => continue,
                        Some(Token {
                            kind: TokenKind::RBracket,
                            end,
                            ..
                        }) => return Ok((Literal::List(items), tok.start, end)),
                        Some(other) => {
                            return Err(FilterError::new(
                                "Expected ',' or ']' in list",
                                other.start,
                                other.end,
                            ));
                        }
                        None => {
                            return Err(FilterError::new(
                                "Unterminated list literal (expected ']')",
                                self.eof_pos(),
                                self.eof_pos(),
                            ));
                        }
                    }
                }
            }
            _ => Err(FilterError::new(
                "Expected literal value (string, number, boolean, null, list, or placeholder)",
                tok.start,
                tok.end,
            )),
        }
    }
}

fn push_flattened_and(out: &mut Vec<FilterNode>, node: FilterNode) {
    match node {
        FilterNode::And(children) => out.extend(children),
        other => out.push(other),
    }
}

fn push_flattened_or(out: &mut Vec<FilterNode>, node: FilterNode) {
    match node {
        FilterNode::Or(children) => out.extend(children),
        other => out.push(other),
    }
}

fn parse_field_ref(raw: &str, start: usize, end: usize) -> Result<FieldRef, FilterError> {
    if raw.eq_ignore_ascii_case("key") {
        return Ok(FieldRef::Key);
    }
    if raw.eq_ignore_ascii_case("timestamp") {
        return Ok(FieldRef::Timestamp);
    }
    if raw.eq_ignore_ascii_case("offset") {
        return Ok(FieldRef::Offset);
    }
    if raw.eq_ignore_ascii_case("partition") {
        return Ok(FieldRef::Partition);
    }

    if let Some(rest) = strip_prefix_ignore_ascii_case(raw, "value.") {
        if rest.is_empty() || FieldPath::parse(rest).is_none() {
            return Err(FilterError::new(
                format!("Invalid value field path '{raw}'"),
                start,
                end,
            ));
        }
        return Ok(FieldRef::Value(rest.to_string()));
    }

    if let Some(rest) = strip_prefix_ignore_ascii_case(raw, "key.") {
        if rest.is_empty() || FieldPath::parse(rest).is_none() {
            return Err(FilterError::new(
                format!("Invalid key field path '{raw}'"),
                start,
                end,
            ));
        }
        return Ok(FieldRef::KeyPath(rest.to_string()));
    }

    if let Some(rest) = strip_prefix_ignore_ascii_case(raw, "header.") {
        let name = unquote_header_name(rest).ok_or_else(|| {
            FilterError::new(format!("Invalid header name in '{raw}'"), start, end)
        })?;
        return Ok(FieldRef::Header(name));
    }

    if let Some(rest) = strip_prefix_ignore_ascii_case(raw, "header[") {
        if let Some(inner) = rest.strip_suffix(']') {
            let name = unquote_header_name(inner).ok_or_else(|| {
                FilterError::new(format!("Invalid header name in '{raw}'"), start, end)
            })?;
            return Ok(FieldRef::Header(name));
        }
    }

    Err(FilterError::new(
        format!("Unknown field source '{raw}' (expected value.<path>, key, key.<path>, header.<name>, timestamp, offset, or partition)"),
        start,
        end,
    ))
}

fn strip_prefix_ignore_ascii_case<'a>(s: &'a str, prefix: &str) -> Option<&'a str> {
    if s.len() >= prefix.len() && s[..prefix.len()].eq_ignore_ascii_case(prefix) {
        Some(&s[prefix.len()..])
    } else {
        None
    }
}

fn unquote_header_name(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    if (trimmed.starts_with('"') && trimmed.ends_with('"') && trimmed.len() >= 2)
        || (trimmed.starts_with('\'') && trimmed.ends_with('\'') && trimmed.len() >= 2)
    {
        let inner = &trimmed[1..trimmed.len() - 1];
        if inner.is_empty() {
            return None;
        }
        Some(
            inner
                .replace("\\\"", "\"")
                .replace("\\'", "'")
                .replace("\\\\", "\\"),
        )
    } else {
        Some(trimmed.to_string())
    }
}

pub fn parse(input: &str) -> Result<FilterNode, FilterError> {
    if input.len() > MAX_EXPRESSION_LEN {
        return Err(FilterError::new(
            format!("Expression exceeds maximum length of {MAX_EXPRESSION_LEN} bytes"),
            MAX_EXPRESSION_LEN,
            input.len(),
        ));
    }
    if input.trim().is_empty() {
        return Err(FilterError::new(
            "Expression cannot be empty",
            0,
            input.len(),
        ));
    }
    let tokens = tokenize(input)?;
    let mut parser = Parser::new(input, tokens);
    let ast = parser.parse_or(0)?;
    if let Some(extra) = parser.peek() {
        return Err(FilterError::new(
            "Unexpected trailing token",
            extra.start,
            extra.end,
        ));
    }
    Ok(ast)
}

// ============================================================================
// Canonical Formatter
// ============================================================================

pub fn format_expr(node: &FilterNode) -> String {
    let mut out = String::new();
    fmt_node(node, &mut out, 0);
    out
}

fn fmt_node(node: &FilterNode, out: &mut String, parent_prec: u8) {
    match node {
        FilterNode::Or(children) => {
            let need_parens = parent_prec > 1;
            if need_parens {
                out.push('(');
            }
            for (idx, child) in children.iter().enumerate() {
                if idx > 0 {
                    out.push_str(" OR ");
                }
                fmt_node(child, out, 1);
            }
            if need_parens {
                out.push(')');
            }
        }
        FilterNode::And(children) => {
            let need_parens = parent_prec > 2;
            if need_parens {
                out.push('(');
            }
            for (idx, child) in children.iter().enumerate() {
                if idx > 0 {
                    out.push_str(" AND ");
                }
                fmt_node(child, out, 2);
            }
            if need_parens {
                out.push(')');
            }
        }
        FilterNode::Not(inner) => {
            out.push_str("NOT ");
            let wrap = matches!(inner.as_ref(), FilterNode::And(_) | FilterNode::Or(_));
            if wrap {
                out.push('(');
                fmt_node(inner, out, 0);
                out.push(')');
            } else {
                fmt_node(inner, out, 3);
            }
        }
        FilterNode::Cond(cond) => {
            fmt_field(&cond.field, out);
            out.push(' ');
            out.push_str(match cond.op {
                CompOp::Eq => "=",
                CompOp::Ne => "!=",
                CompOp::Gt => ">",
                CompOp::Ge => ">=",
                CompOp::Lt => "<",
                CompOp::Le => "<=",
                CompOp::Contains => "contains",
                CompOp::StartsWith => "startsWith",
                CompOp::EndsWith => "endsWith",
                CompOp::Matches => "matches",
                CompOp::In => "in",
                CompOp::Exists => "exists",
                CompOp::IsNull => "is null",
                CompOp::IsNotNull => "is not null",
            });
            if let Some(val) = &cond.value {
                out.push(' ');
                fmt_literal(val, out);
            }
        }
    }
}

fn fmt_field(field: &FieldRef, out: &mut String) {
    match field {
        FieldRef::Value(p) => {
            out.push_str("value.");
            out.push_str(p);
        }
        FieldRef::Key => out.push_str("key"),
        FieldRef::KeyPath(p) => {
            out.push_str("key.");
            out.push_str(p);
        }
        FieldRef::Header(name) => {
            if name
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-' | b'.'))
            {
                out.push_str("header.");
                out.push_str(name);
            } else {
                out.push_str("header.");
                fmt_quoted_str(name, out);
            }
        }
        FieldRef::Timestamp => out.push_str("timestamp"),
        FieldRef::Offset => out.push_str("offset"),
        FieldRef::Partition => out.push_str("partition"),
    }
}

fn fmt_literal(lit: &Literal, out: &mut String) {
    match lit {
        Literal::String(s) => fmt_quoted_str(s, out),
        Literal::Int(n) => out.push_str(&n.to_string()),
        Literal::Float(f) => {
            let s = f.to_string();
            out.push_str(&s);
            if !s.contains('.') && !s.contains('e') && !s.contains('E') {
                out.push_str(".0");
            }
        }
        Literal::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        Literal::Null => out.push_str("null"),
        Literal::Placeholder(name) => {
            out.push_str("{{");
            out.push_str(name);
            out.push_str("}}");
        }
        Literal::List(items) => {
            out.push('[');
            for (idx, item) in items.iter().enumerate() {
                if idx > 0 {
                    out.push_str(", ");
                }
                fmt_literal(item, out);
            }
            out.push(']');
        }
    }
}

fn fmt_quoted_str(s: &str, out: &mut String) {
    out.push('"');
    for ch in s.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c => out.push(c),
        }
    }
    out.push('"');
}

// ============================================================================
// Compiler & Evaluator
// ============================================================================

pub trait MessageView {
    fn partition(&self) -> i32;
    fn offset(&self) -> i64;
    fn timestamp(&self) -> Option<i64>;
    fn header(&self, name: &str) -> Option<&[u8]>;
    fn headers(&self, name: &str) -> Vec<Option<&[u8]>> {
        match self.header(name) {
            Some(v) => vec![Some(v)],
            None => vec![],
        }
    }
    fn key_bytes(&self) -> Option<&[u8]>;
    fn key_json(&self) -> Option<&Value>;
    fn key_text(&self) -> Option<&str>;
    fn value_json(&self) -> Option<&Value>;
    fn value_text(&self) -> Option<&str>;
}

#[derive(Debug, Clone)]
pub struct CompiledExpr {
    root: CompiledNode,
}

#[derive(Debug, Clone)]
enum CompiledNode {
    And(Vec<CompiledNode>),
    Or(Vec<CompiledNode>),
    Not(Box<CompiledNode>),
    Cond(CompiledCondition),
}

#[derive(Debug, Clone)]
struct CompiledCondition {
    source: CompiledSource,
    matcher: CompiledMatcher,
}

#[derive(Debug, Clone)]
enum CompiledSource {
    Value(FieldPath),
    Key,
    KeyPath(FieldPath),
    Header(String),
    Timestamp,
    Offset,
    Partition,
}

#[derive(Debug, Clone)]
enum CompiledMatcher {
    Exists,
    IsNull,
    IsNotNull,
    Single(SingleMatcher),
    /// Evaluates true if ANY matcher in the list matches (used for multi-value script bindings).
    AnyOf(Vec<SingleMatcher>),
}

#[derive(Debug, Clone)]
enum SingleMatcher {
    Eq(ScalarVal),
    Ne(ScalarVal),
    Gt(ScalarVal),
    Ge(ScalarVal),
    Lt(ScalarVal),
    Le(ScalarVal),
    Contains(String),
    StartsWith(String),
    EndsWith(String),
    Matches(Regex),
    In(Vec<ScalarVal>),
}

#[derive(Debug, Clone, PartialEq)]
enum ScalarVal {
    String(String),
    BoundString(String),
    Int(i64),
    Float(f64),
    Bool(bool),
    Null,
}

pub fn compile(
    ast: &FilterNode,
    bindings: &HashMap<String, Vec<String>>,
) -> Result<CompiledExpr, FilterError> {
    let root = compile_node(ast, bindings)?;
    Ok(CompiledExpr { root })
}

pub fn compile_str(
    input: &str,
    bindings: &HashMap<String, Vec<String>>,
) -> Result<CompiledExpr, FilterError> {
    let ast = parse(input)?;
    compile(&ast, bindings)
}

fn compile_node(
    node: &FilterNode,
    bindings: &HashMap<String, Vec<String>>,
) -> Result<CompiledNode, FilterError> {
    match node {
        FilterNode::And(children) => Ok(CompiledNode::And(
            children
                .iter()
                .map(|c| compile_node(c, bindings))
                .collect::<Result<Vec<_>, _>>()?,
        )),
        FilterNode::Or(children) => Ok(CompiledNode::Or(
            children
                .iter()
                .map(|c| compile_node(c, bindings))
                .collect::<Result<Vec<_>, _>>()?,
        )),
        FilterNode::Not(inner) => Ok(CompiledNode::Not(Box::new(compile_node(inner, bindings)?))),
        FilterNode::Cond(cond) => Ok(CompiledNode::Cond(compile_condition(cond, bindings)?)),
    }
}

fn compile_condition(
    cond: &FilterCondition,
    bindings: &HashMap<String, Vec<String>>,
) -> Result<CompiledCondition, FilterError> {
    let source = match &cond.field {
        FieldRef::Value(p) => CompiledSource::Value(
            FieldPath::parse(p)
                .ok_or_else(|| FilterError::new(format!("Invalid value path '{p}'"), 0, 0))?,
        ),
        FieldRef::Key => CompiledSource::Key,
        FieldRef::KeyPath(p) => CompiledSource::KeyPath(
            FieldPath::parse(p)
                .ok_or_else(|| FilterError::new(format!("Invalid key path '{p}'"), 0, 0))?,
        ),
        FieldRef::Header(name) => CompiledSource::Header(name.clone()),
        FieldRef::Timestamp => CompiledSource::Timestamp,
        FieldRef::Offset => CompiledSource::Offset,
        FieldRef::Partition => CompiledSource::Partition,
    };

    let matcher = match cond.op {
        CompOp::Exists => CompiledMatcher::Exists,
        CompOp::IsNull => CompiledMatcher::IsNull,
        CompOp::IsNotNull => CompiledMatcher::IsNotNull,
        op => {
            let lit = cond
                .value
                .as_ref()
                .ok_or_else(|| FilterError::new("Missing value for comparison operator", 0, 0))?;
            match lit {
                Literal::Placeholder(var_name) => {
                    let values = bindings.get(var_name).ok_or_else(|| {
                        FilterError::new(
                            format!("Unbound script variable '{{{{{var_name}}}}}'"),
                            0,
                            0,
                        )
                    })?;
                    if op == CompOp::In {
                        let scalars = values
                            .iter()
                            .map(|v| parse_bound_scalar(&source, v))
                            .collect::<Result<Vec<_>, _>>()?;
                        CompiledMatcher::Single(SingleMatcher::In(scalars))
                    } else {
                        let matchers = values
                            .iter()
                            .map(|v| compile_single_from_binding(&source, op, v))
                            .collect::<Result<Vec<_>, _>>()?;
                        CompiledMatcher::AnyOf(matchers)
                    }
                }
                other => CompiledMatcher::Single(compile_single_literal(&source, op, other)?),
            }
        }
    };

    Ok(CompiledCondition { source, matcher })
}

fn compile_single_from_binding(
    source: &CompiledSource,
    op: CompOp,
    raw: &str,
) -> Result<SingleMatcher, FilterError> {
    match op {
        CompOp::Contains => Ok(SingleMatcher::Contains(raw.to_string())),
        CompOp::StartsWith => Ok(SingleMatcher::StartsWith(raw.to_string())),
        CompOp::EndsWith => Ok(SingleMatcher::EndsWith(raw.to_string())),
        CompOp::Matches => {
            let re = Regex::new(raw)
                .map_err(|e| FilterError::new(format!("Invalid regex '{raw}': {e}"), 0, 0))?;
            Ok(SingleMatcher::Matches(re))
        }
        _ => {
            let scalar = parse_bound_scalar(source, raw)?;
            make_scalar_matcher(op, scalar)
        }
    }
}

fn parse_bound_scalar(source: &CompiledSource, raw: &str) -> Result<ScalarVal, FilterError> {
    match source {
        CompiledSource::Timestamp => {
            if let Ok(ms) = raw.parse::<i64>() {
                Ok(ScalarVal::Int(ms))
            } else {
                parse_timestamp_literal(raw).map(ScalarVal::Int)
            }
        }
        CompiledSource::Offset | CompiledSource::Partition => {
            let n = raw.parse::<i64>().map_err(|_| {
                FilterError::new(
                    format!("Expected integer for offset/partition, got '{raw}'"),
                    0,
                    0,
                )
            })?;
            Ok(ScalarVal::Int(n))
        }
        _ => Ok(ScalarVal::BoundString(raw.to_string())),
    }
}

fn compile_single_literal(
    source: &CompiledSource,
    op: CompOp,
    lit: &Literal,
) -> Result<SingleMatcher, FilterError> {
    match op {
        CompOp::Contains | CompOp::StartsWith | CompOp::EndsWith | CompOp::Matches => {
            if matches!(
                source,
                CompiledSource::Timestamp | CompiledSource::Offset | CompiledSource::Partition
            ) {
                return Err(FilterError::new(
                    "String/regex operators are only supported on value, key, and header fields",
                    0,
                    0,
                ));
            }
        }
        _ => {}
    }

    match op {
        CompOp::Contains => match lit {
            Literal::String(s) => Ok(SingleMatcher::Contains(s.clone())),
            _ => Err(FilterError::new(
                "'contains' requires a string literal",
                0,
                0,
            )),
        },
        CompOp::StartsWith => match lit {
            Literal::String(s) => Ok(SingleMatcher::StartsWith(s.clone())),
            _ => Err(FilterError::new(
                "'startsWith' requires a string literal",
                0,
                0,
            )),
        },
        CompOp::EndsWith => match lit {
            Literal::String(s) => Ok(SingleMatcher::EndsWith(s.clone())),
            _ => Err(FilterError::new(
                "'endsWith' requires a string literal",
                0,
                0,
            )),
        },
        CompOp::Matches => match lit {
            Literal::String(s) => {
                let re = Regex::new(s)
                    .map_err(|e| FilterError::new(format!("Invalid regex '{s}': {e}"), 0, 0))?;
                Ok(SingleMatcher::Matches(re))
            }
            _ => Err(FilterError::new(
                "'matches' requires a string literal",
                0,
                0,
            )),
        },
        CompOp::In => match lit {
            Literal::List(items) => {
                let scalars = items
                    .iter()
                    .map(|item| literal_to_scalar(source, item))
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(SingleMatcher::In(scalars))
            }
            _ => Err(FilterError::new("'in' requires a list literal", 0, 0)),
        },
        _ => {
            let scalar = literal_to_scalar(source, lit)?;
            if matches!(op, CompOp::Gt | CompOp::Ge | CompOp::Lt | CompOp::Le)
                && matches!(scalar, ScalarVal::Bool(_) | ScalarVal::Null)
            {
                return Err(FilterError::new(
                    "Ordering operators (<, <=, >, >=) cannot be used with boolean or null literals",
                    0,
                    0,
                ));
            }
            make_scalar_matcher(op, scalar)
        }
    }
}

fn make_scalar_matcher(op: CompOp, scalar: ScalarVal) -> Result<SingleMatcher, FilterError> {
    match op {
        CompOp::Eq => Ok(SingleMatcher::Eq(scalar)),
        CompOp::Ne => Ok(SingleMatcher::Ne(scalar)),
        CompOp::Gt => Ok(SingleMatcher::Gt(scalar)),
        CompOp::Ge => Ok(SingleMatcher::Ge(scalar)),
        CompOp::Lt => Ok(SingleMatcher::Lt(scalar)),
        CompOp::Le => Ok(SingleMatcher::Le(scalar)),
        _ => Err(FilterError::new("Unsupported scalar operator", 0, 0)),
    }
}

fn literal_to_scalar(source: &CompiledSource, lit: &Literal) -> Result<ScalarVal, FilterError> {
    match source {
        CompiledSource::Timestamp => match lit {
            Literal::Int(ms) => Ok(ScalarVal::Int(*ms)),
            Literal::String(s) => parse_timestamp_literal(s).map(ScalarVal::Int),
            _ => Err(FilterError::new(
                "Timestamp must be compared with an RFC3339/ISO-8601 string or epoch milliseconds",
                0,
                0,
            )),
        },
        CompiledSource::Offset | CompiledSource::Partition => match lit {
            Literal::Int(n) => Ok(ScalarVal::Int(*n)),
            _ => Err(FilterError::new(
                "Offset and partition must be compared with an integer",
                0,
                0,
            )),
        },
        _ => match lit {
            Literal::String(s) => Ok(ScalarVal::String(s.clone())),
            Literal::Int(n) => Ok(ScalarVal::Int(*n)),
            Literal::Float(f) => Ok(ScalarVal::Float(*f)),
            Literal::Bool(b) => Ok(ScalarVal::Bool(*b)),
            Literal::Null => Ok(ScalarVal::Null),
            _ => Err(FilterError::new("Invalid scalar literal", 0, 0)),
        },
    }
}

fn parse_timestamp_literal(s: &str) -> Result<i64, FilterError> {
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return Ok(dt.timestamp_millis());
    }
    Err(FilterError::new(
        format!("Invalid timestamp literal '{s}' (expected RFC3339 with timezone offset)"),
        0,
        0,
    ))
}

impl CompiledExpr {
    pub fn evaluate(&self, msg: &dyn MessageView) -> bool {
        eval_node(&self.root, msg)
    }
}

fn eval_node(node: &CompiledNode, msg: &dyn MessageView) -> bool {
    match node {
        CompiledNode::And(children) => children.iter().all(|c| eval_node(c, msg)),
        CompiledNode::Or(children) => children.iter().any(|c| eval_node(c, msg)),
        CompiledNode::Not(inner) => !eval_node(inner, msg),
        CompiledNode::Cond(cond) => eval_condition(cond, msg),
    }
}

fn eval_condition(cond: &CompiledCondition, msg: &dyn MessageView) -> bool {
    match &cond.source {
        CompiledSource::Partition => eval_int_matcher(msg.partition() as i64, &cond.matcher),
        CompiledSource::Offset => eval_int_matcher(msg.offset(), &cond.matcher),
        CompiledSource::Timestamp => match msg.timestamp() {
            Some(ts) => eval_int_matcher(ts, &cond.matcher),
            None => false,
        },
        CompiledSource::Header(name) => {
            let vals = msg.headers(name);
            if vals.is_empty() {
                return false;
            }
            if matches!(cond.matcher, CompiledMatcher::Exists) {
                return true;
            }
            vals.into_iter().any(|opt_bytes| match opt_bytes {
                None => matches!(cond.matcher, CompiledMatcher::IsNull),
                Some(bytes) => {
                    if matches!(cond.matcher, CompiledMatcher::IsNotNull) {
                        return true;
                    }
                    if matches!(cond.matcher, CompiledMatcher::IsNull) {
                        return false;
                    }
                    match std::str::from_utf8(bytes) {
                        Ok(text) => eval_text_matcher(text, &cond.matcher),
                        Err(_) => false,
                    }
                }
            })
        }
        CompiledSource::Key => {
            if matches!(cond.matcher, CompiledMatcher::Exists) {
                return msg.key_bytes().is_some() || msg.key_text().is_some();
            }
            if matches!(cond.matcher, CompiledMatcher::IsNull) {
                return matches!(msg.key_json(), Some(Value::Null));
            }
            if matches!(cond.matcher, CompiledMatcher::IsNotNull) {
                return (msg.key_bytes().is_some() || msg.key_text().is_some())
                    && !matches!(msg.key_json(), Some(Value::Null));
            }
            if let Some(text) = msg.key_text() {
                eval_text_matcher(text, &cond.matcher)
            } else if let Some(bytes) = msg.key_bytes() {
                match std::str::from_utf8(bytes) {
                    Ok(text) => eval_text_matcher(text, &cond.matcher),
                    Err(_) => false,
                }
            } else {
                false
            }
        }
        CompiledSource::KeyPath(path) => match msg.key_json().and_then(|v| path.lookup(v)) {
            Some(val) => eval_json_matcher(val, &cond.matcher),
            None => false,
        },
        CompiledSource::Value(path) => match msg.value_json().and_then(|v| path.lookup(v)) {
            Some(val) => eval_json_matcher(val, &cond.matcher),
            None => false,
        },
    }
}

fn eval_int_matcher(actual: i64, matcher: &CompiledMatcher) -> bool {
    match matcher {
        CompiledMatcher::Exists | CompiledMatcher::IsNotNull => true,
        CompiledMatcher::IsNull => false,
        CompiledMatcher::Single(m) => eval_int_single(actual, m),
        CompiledMatcher::AnyOf(ms) => ms.iter().any(|m| eval_int_single(actual, m)),
    }
}

fn eval_int_single(actual: i64, m: &SingleMatcher) -> bool {
    match m {
        SingleMatcher::Eq(ScalarVal::Int(n)) => actual == *n,
        SingleMatcher::Ne(ScalarVal::Int(n)) => actual != *n,
        SingleMatcher::Gt(ScalarVal::Int(n)) => actual > *n,
        SingleMatcher::Ge(ScalarVal::Int(n)) => actual >= *n,
        SingleMatcher::Lt(ScalarVal::Int(n)) => actual < *n,
        SingleMatcher::Le(ScalarVal::Int(n)) => actual <= *n,
        SingleMatcher::In(list) => list
            .iter()
            .any(|s| matches!(s, ScalarVal::Int(n) if actual == *n)),
        _ => false,
    }
}

fn eval_text_matcher(actual: &str, matcher: &CompiledMatcher) -> bool {
    match matcher {
        CompiledMatcher::Exists | CompiledMatcher::IsNotNull => true,
        CompiledMatcher::IsNull => false,
        CompiledMatcher::Single(m) => eval_text_single(actual, m),
        CompiledMatcher::AnyOf(ms) => ms.iter().any(|m| eval_text_single(actual, m)),
    }
}

fn eval_text_single(actual: &str, m: &SingleMatcher) -> bool {
    match m {
        SingleMatcher::Eq(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual == s,
        SingleMatcher::Ne(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual != s,
        SingleMatcher::Gt(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual > s.as_str(),
        SingleMatcher::Ge(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual >= s.as_str(),
        SingleMatcher::Lt(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual < s.as_str(),
        SingleMatcher::Le(ScalarVal::String(s) | ScalarVal::BoundString(s)) => actual <= s.as_str(),
        SingleMatcher::Eq(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a == *n),
        SingleMatcher::Ne(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a != *n),
        SingleMatcher::Gt(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a > *n),
        SingleMatcher::Ge(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a >= *n),
        SingleMatcher::Lt(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a < *n),
        SingleMatcher::Le(ScalarVal::Int(n)) => actual.parse::<i64>().is_ok_and(|a| a <= *n),
        SingleMatcher::Contains(s) => actual.contains(s.as_str()),
        SingleMatcher::StartsWith(s) => actual.starts_with(s.as_str()),
        SingleMatcher::EndsWith(s) => actual.ends_with(s.as_str()),
        SingleMatcher::Matches(re) => re.is_match(actual),
        SingleMatcher::In(list) => list.iter().any(|s| match s {
            ScalarVal::String(sv) | ScalarVal::BoundString(sv) => actual == sv,
            ScalarVal::Int(n) => actual.parse::<i64>().is_ok_and(|a| a == *n),
            _ => false,
        }),
        _ => false,
    }
}

fn eval_json_matcher(actual: &Value, matcher: &CompiledMatcher) -> bool {
    match matcher {
        CompiledMatcher::Exists => true,
        CompiledMatcher::IsNull => actual.is_null(),
        CompiledMatcher::IsNotNull => !actual.is_null(),
        CompiledMatcher::Single(m) => eval_json_single(actual, m),
        CompiledMatcher::AnyOf(ms) => ms.iter().any(|m| eval_json_single(actual, m)),
    }
}

fn eval_json_single(actual: &Value, m: &SingleMatcher) -> bool {
    match m {
        SingleMatcher::Contains(s) => actual.as_str().is_some_and(|a| a.contains(s.as_str())),
        SingleMatcher::StartsWith(s) => actual.as_str().is_some_and(|a| a.starts_with(s.as_str())),
        SingleMatcher::EndsWith(s) => actual.as_str().is_some_and(|a| a.ends_with(s.as_str())),
        SingleMatcher::Matches(re) => actual.as_str().is_some_and(|a| re.is_match(a)),
        SingleMatcher::Eq(s) => cmp_json_scalar(actual, s) == Some(std::cmp::Ordering::Equal),
        SingleMatcher::Ne(s) => {
            // Note: Null vs non-Null or type mismatch: only true when comparable or null vs non-null?
            // Spec: "Typed Comparison" / "Unresolvable Values Make A Condition False"
            cmp_json_scalar(actual, s).is_some_and(|ord| ord != std::cmp::Ordering::Equal)
        }
        SingleMatcher::Gt(s) => cmp_json_scalar(actual, s) == Some(std::cmp::Ordering::Greater),
        SingleMatcher::Ge(s) => matches!(
            cmp_json_scalar(actual, s),
            Some(std::cmp::Ordering::Greater | std::cmp::Ordering::Equal)
        ),
        SingleMatcher::Lt(s) => cmp_json_scalar(actual, s) == Some(std::cmp::Ordering::Less),
        SingleMatcher::Le(s) => matches!(
            cmp_json_scalar(actual, s),
            Some(std::cmp::Ordering::Less | std::cmp::Ordering::Equal)
        ),
        SingleMatcher::In(list) => list
            .iter()
            .any(|s| cmp_json_scalar(actual, s) == Some(std::cmp::Ordering::Equal)),
    }
}

fn cmp_json_scalar(actual: &Value, expected: &ScalarVal) -> Option<std::cmp::Ordering> {
    match (actual, expected) {
        (Value::Null, ScalarVal::Null) => Some(std::cmp::Ordering::Equal),
        (Value::Bool(a), ScalarVal::Bool(b)) => Some(a.cmp(b)),
        (Value::String(a), ScalarVal::String(b) | ScalarVal::BoundString(b)) => Some(a.cmp(b)),
        (Value::Number(n), ScalarVal::Int(b)) => {
            if let Some(a) = n.as_i64() {
                Some(a.cmp(b))
            } else if let Some(a) = n.as_u64() {
                if *b < 0 {
                    Some(std::cmp::Ordering::Greater)
                } else {
                    Some(a.cmp(&(*b as u64)))
                }
            } else if let Some(a) = n.as_f64() {
                a.partial_cmp(&(*b as f64))
            } else {
                None
            }
        }
        (Value::Number(n), ScalarVal::Float(b)) => n.as_f64().and_then(|a| a.partial_cmp(b)),
        // Script bindings come in as strings; allow coerced comparison against typed JSON values
        (Value::Number(n), ScalarVal::BoundString(s)) => {
            if let Ok(b) = s.parse::<i64>() {
                cmp_json_scalar(actual, &ScalarVal::Int(b))
            } else if let Ok(b) = s.parse::<f64>() {
                n.as_f64().and_then(|a| a.partial_cmp(&b))
            } else {
                None
            }
        }
        (Value::Bool(a), ScalarVal::BoundString(s)) => {
            if s.eq_ignore_ascii_case("true") {
                Some(a.cmp(&true))
            } else if s.eq_ignore_ascii_case("false") {
                Some(a.cmp(&false))
            } else {
                None
            }
        }
        (Value::Null, ScalarVal::BoundString(s)) if s.eq_ignore_ascii_case("null") => {
            Some(std::cmp::Ordering::Equal)
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    struct MockMsg<'a> {
        partition: i32,
        offset: i64,
        timestamp: Option<i64>,
        headers: Vec<(&'a str, &'a [u8])>,
        key_bytes: Option<&'a [u8]>,
        key_json: Option<Value>,
        key_text: Option<&'a str>,
        value_json: Option<Value>,
        value_text: Option<&'a str>,
        value_reads: Cell<usize>,
    }

    impl<'a> Default for MockMsg<'a> {
        fn default() -> Self {
            Self {
                partition: 0,
                offset: 0,
                timestamp: Some(1_736_937_000_000),
                headers: vec![],
                key_bytes: None,
                key_json: None,
                key_text: None,
                value_json: None,
                value_text: None,
                value_reads: Cell::new(0),
            }
        }
    }

    impl<'a> MessageView for MockMsg<'a> {
        fn partition(&self) -> i32 {
            self.partition
        }
        fn offset(&self) -> i64 {
            self.offset
        }
        fn timestamp(&self) -> Option<i64> {
            self.timestamp
        }
        fn header(&self, name: &str) -> Option<&[u8]> {
            self.headers
                .iter()
                .find(|(k, _)| *k == name)
                .map(|(_, v)| *v)
        }
        fn key_bytes(&self) -> Option<&[u8]> {
            self.key_bytes
        }
        fn key_json(&self) -> Option<&Value> {
            self.key_json.as_ref()
        }
        fn key_text(&self) -> Option<&str> {
            self.key_text
        }
        fn value_json(&self) -> Option<&Value> {
            self.value_reads.set(self.value_reads.get() + 1);
            self.value_json.as_ref()
        }
        fn value_text(&self) -> Option<&str> {
            self.value_text
        }
    }

    #[test]
    fn parse_precedence_and_normalization() {
        let ast = parse("a = 1").unwrap_err();
        assert_eq!(ast.start, 0);

        let ast = parse("value.a = 1 or not value.b = 2 and value.c = 3").unwrap();
        assert_eq!(
            format_expr(&ast),
            "value.a = 1 OR NOT value.b = 2 AND value.c = 3"
        );
        let round_trip = parse(&format_expr(&ast)).unwrap();
        assert_eq!(ast, round_trip);
    }

    #[test]
    fn parse_parentheses_and_flattening() {
        let ast = parse("((value.a = 1 and value.b = 2) and value.c = 3)").unwrap();
        assert_eq!(
            format_expr(&ast),
            "value.a = 1 AND value.b = 2 AND value.c = 3"
        );

        let ast2 = parse("NOT (value.a = 1 OR value.b = 2)").unwrap();
        assert_eq!(format_expr(&ast2), "NOT (value.a = 1 OR value.b = 2)");
        assert_eq!(parse(&format_expr(&ast2)).unwrap(), ast2);

        // README example expression
        let readme_expr = r#"(header.eventType = "OrderCreated" OR value.status = "FAILED") AND NOT partition = 0"#;
        assert!(parse(readme_expr).is_ok());
    }

    #[test]
    fn parse_all_sources_and_operators() {
        let expr = concat!(
            "value.user.id = \"u-1\" AND ",
            "key = \"k-1\" AND ",
            "key.tenant in [\"t1\", \"t2\"] AND ",
            "header.x-request-id startsWith \"req-\" AND ",
            "timestamp >= \"2025-01-15T00:00:00Z\" AND ",
            "offset > 100 AND ",
            "partition = 2 AND ",
            "value.deleted is null AND ",
            "value.email is not null AND ",
            "value.tags exists AND ",
            "value.name matches \"^Al.*\""
        );
        let ast = parse(expr).unwrap();
        let formatted = format_expr(&ast);
        assert_eq!(parse(&formatted).unwrap(), ast);
    }

    #[test]
    fn parse_errors_have_accurate_spans() {
        let err = parse("value.a = 1 AND unknown.field = 2").unwrap_err();
        assert_eq!(
            &"value.a = 1 AND unknown.field = 2"[err.start..err.end],
            "unknown.field"
        );

        let err2 = parse("value.a = \"unterminated").unwrap_err();
        assert_eq!(err2.start, 10);

        let err3 = parse("value.a = \"héllo\" AND foo = 1").unwrap_err();
        let (u16_start, u16_end) = err3.span_utf16("value.a = \"héllo\" AND foo = 1");
        assert_eq!(u16_start, 22);
        assert_eq!(u16_end, 25);
    }

    #[test]
    fn limits_are_enforced() {
        let too_long = "a".repeat(MAX_EXPRESSION_LEN + 1);
        assert!(parse(&too_long).is_err());

        let deep = format!(
            "{}value.a = 1{}",
            "(".repeat(MAX_AST_DEPTH + 1),
            ")".repeat(MAX_AST_DEPTH + 1)
        );
        assert!(parse(&deep).is_err());

        let many_conds = (0..=MAX_CONDITIONS)
            .map(|i| format!("value.f{i} = 1"))
            .collect::<Vec<_>>()
            .join(" AND ");
        assert!(parse(&many_conds).is_err());

        let many_in = (0..=MAX_IN_LIST_ITEMS)
            .map(|i| i.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        assert!(parse(&format!("value.a in [{many_in}]")).is_err());
    }

    #[test]
    fn evaluator_typed_and_unresolvable_semantics() {
        let mut msg = MockMsg::default();
        msg.value_json = Some(serde_json::json!({
            "count": 42,
            "price": 19.5,
            "active": true,
            "deleted": null,
            "name": "Alice",
            "items": [{"sku": "ABC-1"}]
        }));
        msg.headers = vec![("x-env", b"prod")];
        msg.key_text = Some("order-99");
        msg.key_bytes = Some(b"order-99");
        msg.partition = 3;
        msg.offset = 500;

        assert!(
            compile_str("value.count = 42 AND value.price > 19.0", &HashMap::new())
                .unwrap()
                .evaluate(&msg)
        );
        assert!(!compile_str("value.count = \"42\"", &HashMap::new())
            .unwrap()
            .evaluate(&msg));
        assert!(compile_str("value.deleted is null", &HashMap::new())
            .unwrap()
            .evaluate(&msg));
        assert!(!compile_str("value.missing is null", &HashMap::new())
            .unwrap()
            .evaluate(&msg));
        assert!(!compile_str("value.missing != \"x\"", &HashMap::new())
            .unwrap()
            .evaluate(&msg));
        assert!(compile_str("NOT (value.missing = \"x\")", &HashMap::new())
            .unwrap()
            .evaluate(&msg));
        assert!(
            compile_str("value.items[0].sku endsWith \"-1\"", &HashMap::new())
                .unwrap()
                .evaluate(&msg)
        );
        assert!(compile_str(
            "header.x-env = \"prod\" AND key startsWith \"order-\"",
            &HashMap::new()
        )
        .unwrap()
        .evaluate(&msg));
    }

    #[test]
    fn evaluator_short_circuits_value_access() {
        let mut msg = MockMsg::default();
        msg.partition = 1;
        msg.value_json = Some(serde_json::json!({"a": 1}));

        let compiled = compile_str("partition = 2 AND value.a = 1", &HashMap::new()).unwrap();
        assert!(!compiled.evaluate(&msg));
        assert_eq!(msg.value_reads.get(), 0);
    }

    #[test]
    fn script_placeholders_single_and_multi_value() {
        let mut bindings = HashMap::new();
        bindings.insert(
            "userId".to_string(),
            vec!["u1".to_string(), "u2".to_string()],
        );
        bindings.insert("minOffset".to_string(), vec!["100".to_string()]);

        let compiled = compile_str(
            "value.userId = {{userId}} AND offset >= {{minOffset}}",
            &bindings,
        )
        .unwrap();

        let mut msg = MockMsg::default();
        msg.offset = 100;
        msg.value_json = Some(serde_json::json!({"userId": "u2"}));
        assert!(compiled.evaluate(&msg));

        msg.value_json = Some(serde_json::json!({"userId": "u3"}));
        assert!(!compiled.evaluate(&msg));

        // Unbound variable fails at compile time
        assert!(compile_str("value.id = {{missing}}", &bindings).is_err());
    }

    #[test]
    fn timestamp_literals_compile_and_eval() {
        let mut msg = MockMsg::default();
        msg.timestamp = Some(
            DateTime::parse_from_rfc3339("2025-01-15T12:00:00Z")
                .unwrap()
                .timestamp_millis(),
        );
        assert!(
            compile_str("timestamp >= \"2025-01-15T10:00:00Z\"", &HashMap::new())
                .unwrap()
                .evaluate(&msg)
        );
        assert!(compile_str("timestamp >= \"2025-01-15\"", &HashMap::new()).is_err());
        assert!(compile_str("timestamp >= \"not-a-timestamp\"", &HashMap::new()).is_err());
        msg.timestamp = None;
        assert!(
            !compile_str("timestamp >= \"2025-01-15T00:00:00Z\"", &HashMap::new())
                .unwrap()
                .evaluate(&msg)
        );
    }
}
