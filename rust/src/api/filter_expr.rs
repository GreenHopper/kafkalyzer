use anyhow::Result;
use kafkalyzer_core::filter_expr::{
    format_expr, parse, CompOp, FieldRef, FilterCondition, FilterNode, Literal,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterNodeKind {
    And,
    Or,
    Not,
    Cond,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterFieldKind {
    Value,
    Key,
    KeyPath,
    Header,
    Timestamp,
    Offset,
    Partition,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterOpDto {
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterScalarKind {
    String,
    Int,
    Float,
    Bool,
    Null,
    Placeholder,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FilterScalarDto {
    pub kind: FilterScalarKind,
    pub text: String,
    pub int_val: Option<i64>,
    pub float_val: Option<f64>,
    pub bool_val: Option<bool>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FilterConditionDto {
    pub field_kind: FilterFieldKind,
    pub field_path: Option<String>,
    pub op: FilterOpDto,
    pub scalar: Option<FilterScalarDto>,
    pub list_items: Vec<FilterScalarDto>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FilterNodeDto {
    pub kind: FilterNodeKind,
    pub children: Vec<u32>,
    pub condition: Option<FilterConditionDto>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FilterErrorDto {
    pub message: String,
    pub start_utf16: u32,
    pub end_utf16: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FilterParseResultDto {
    pub ok: bool,
    pub nodes: Vec<FilterNodeDto>,
    pub canonical: Option<String>,
    pub error: Option<FilterErrorDto>,
}

fn scalar_to_dto(lit: &Literal) -> Result<FilterScalarDto> {
    match lit {
        Literal::String(s) => Ok(FilterScalarDto {
            kind: FilterScalarKind::String,
            text: s.clone(),
            int_val: None,
            float_val: None,
            bool_val: None,
        }),
        Literal::Int(n) => Ok(FilterScalarDto {
            kind: FilterScalarKind::Int,
            text: n.to_string(),
            int_val: Some(*n),
            float_val: None,
            bool_val: None,
        }),
        Literal::Float(f) => Ok(FilterScalarDto {
            kind: FilterScalarKind::Float,
            text: f.to_string(),
            int_val: None,
            float_val: Some(*f),
            bool_val: None,
        }),
        Literal::Bool(b) => Ok(FilterScalarDto {
            kind: FilterScalarKind::Bool,
            text: b.to_string(),
            int_val: None,
            float_val: None,
            bool_val: Some(*b),
        }),
        Literal::Null => Ok(FilterScalarDto {
            kind: FilterScalarKind::Null,
            text: "null".to_string(),
            int_val: None,
            float_val: None,
            bool_val: None,
        }),
        Literal::Placeholder(p) => Ok(FilterScalarDto {
            kind: FilterScalarKind::Placeholder,
            text: p.clone(),
            int_val: None,
            float_val: None,
            bool_val: None,
        }),
        Literal::List(_) => anyhow::bail!("Nested list literals are not supported"),
    }
}

fn dto_to_scalar(dto: &FilterScalarDto) -> Literal {
    match dto.kind {
        FilterScalarKind::String => Literal::String(dto.text.clone()),
        FilterScalarKind::Int => {
            Literal::Int(dto.int_val.unwrap_or_else(|| dto.text.parse().unwrap_or(0)))
        }
        FilterScalarKind::Float => Literal::Float(
            dto.float_val
                .unwrap_or_else(|| dto.text.parse().unwrap_or(0.0)),
        ),
        FilterScalarKind::Bool => Literal::Bool(dto.bool_val.unwrap_or(dto.text == "true")),
        FilterScalarKind::Null => Literal::Null,
        FilterScalarKind::Placeholder => Literal::Placeholder(dto.text.clone()),
    }
}

fn cond_to_dto(cond: &FilterCondition) -> Result<FilterConditionDto> {
    let (field_kind, field_path) = match &cond.field {
        FieldRef::Value(p) => (FilterFieldKind::Value, Some(p.clone())),
        FieldRef::Key => (FilterFieldKind::Key, None),
        FieldRef::KeyPath(p) => (FilterFieldKind::KeyPath, Some(p.clone())),
        FieldRef::Header(n) => (FilterFieldKind::Header, Some(n.clone())),
        FieldRef::Timestamp => (FilterFieldKind::Timestamp, None),
        FieldRef::Offset => (FilterFieldKind::Offset, None),
        FieldRef::Partition => (FilterFieldKind::Partition, None),
    };
    let op = match cond.op {
        CompOp::Eq => FilterOpDto::Eq,
        CompOp::Ne => FilterOpDto::Ne,
        CompOp::Gt => FilterOpDto::Gt,
        CompOp::Ge => FilterOpDto::Ge,
        CompOp::Lt => FilterOpDto::Lt,
        CompOp::Le => FilterOpDto::Le,
        CompOp::Contains => FilterOpDto::Contains,
        CompOp::StartsWith => FilterOpDto::StartsWith,
        CompOp::EndsWith => FilterOpDto::EndsWith,
        CompOp::Matches => FilterOpDto::Matches,
        CompOp::In => FilterOpDto::In,
        CompOp::Exists => FilterOpDto::Exists,
        CompOp::IsNull => FilterOpDto::IsNull,
        CompOp::IsNotNull => FilterOpDto::IsNotNull,
    };
    let (scalar, list_items) = match &cond.value {
        None => (None, Vec::new()),
        Some(Literal::List(items)) => (
            None,
            items
                .iter()
                .map(scalar_to_dto)
                .collect::<Result<Vec<_>>>()?,
        ),
        Some(other) => (Some(scalar_to_dto(other)?), Vec::new()),
    };
    Ok(FilterConditionDto {
        field_kind,
        field_path,
        op,
        scalar,
        list_items,
    })
}

fn dto_to_cond(dto: &FilterConditionDto) -> Result<FilterCondition> {
    let field = match dto.field_kind {
        FilterFieldKind::Value => FieldRef::Value(dto.field_path.clone().unwrap_or_default()),
        FilterFieldKind::Key => FieldRef::Key,
        FilterFieldKind::KeyPath => FieldRef::KeyPath(dto.field_path.clone().unwrap_or_default()),
        FilterFieldKind::Header => FieldRef::Header(dto.field_path.clone().unwrap_or_default()),
        FilterFieldKind::Timestamp => FieldRef::Timestamp,
        FilterFieldKind::Offset => FieldRef::Offset,
        FilterFieldKind::Partition => FieldRef::Partition,
    };
    let op = match dto.op {
        FilterOpDto::Eq => CompOp::Eq,
        FilterOpDto::Ne => CompOp::Ne,
        FilterOpDto::Gt => CompOp::Gt,
        FilterOpDto::Ge => CompOp::Ge,
        FilterOpDto::Lt => CompOp::Lt,
        FilterOpDto::Le => CompOp::Le,
        FilterOpDto::Contains => CompOp::Contains,
        FilterOpDto::StartsWith => CompOp::StartsWith,
        FilterOpDto::EndsWith => CompOp::EndsWith,
        FilterOpDto::Matches => CompOp::Matches,
        FilterOpDto::In => CompOp::In,
        FilterOpDto::Exists => CompOp::Exists,
        FilterOpDto::IsNull => CompOp::IsNull,
        FilterOpDto::IsNotNull => CompOp::IsNotNull,
    };
    let value = if op.is_unary() {
        None
    } else if op == CompOp::In && dto.scalar.is_none() {
        Some(Literal::List(
            dto.list_items.iter().map(dto_to_scalar).collect(),
        ))
    } else if let Some(s) = &dto.scalar {
        Some(dto_to_scalar(s))
    } else {
        anyhow::bail!("Missing scalar value for operator");
    };
    Ok(FilterCondition { field, op, value })
}

pub(crate) fn ast_to_flat_dtos(node: &FilterNode) -> Result<Vec<FilterNodeDto>> {
    fn push_node(node: &FilterNode, out: &mut Vec<FilterNodeDto>) -> Result<u32> {
        let idx = out.len() as u32;
        out.push(FilterNodeDto {
            kind: FilterNodeKind::Cond,
            children: Vec::new(),
            condition: None,
        });
        match node {
            FilterNode::And(children) => {
                let mut child_ids = Vec::with_capacity(children.len());
                for c in children {
                    child_ids.push(push_node(c, out)?);
                }
                out[idx as usize] = FilterNodeDto {
                    kind: FilterNodeKind::And,
                    children: child_ids,
                    condition: None,
                };
            }
            FilterNode::Or(children) => {
                let mut child_ids = Vec::with_capacity(children.len());
                for c in children {
                    child_ids.push(push_node(c, out)?);
                }
                out[idx as usize] = FilterNodeDto {
                    kind: FilterNodeKind::Or,
                    children: child_ids,
                    condition: None,
                };
            }
            FilterNode::Not(inner) => {
                let child_id = push_node(inner, out)?;
                out[idx as usize] = FilterNodeDto {
                    kind: FilterNodeKind::Not,
                    children: vec![child_id],
                    condition: None,
                };
            }
            FilterNode::Cond(cond) => {
                out[idx as usize] = FilterNodeDto {
                    kind: FilterNodeKind::Cond,
                    children: Vec::new(),
                    condition: Some(cond_to_dto(cond)?),
                };
            }
        }
        Ok(idx)
    }

    let mut out = Vec::new();
    push_node(node, &mut out)?;
    Ok(out)
}

pub(crate) fn flat_dtos_to_ast(nodes: &[FilterNodeDto]) -> Result<FilterNode> {
    fn build(nodes: &[FilterNodeDto], idx: u32, depth: usize) -> Result<FilterNode> {
        if depth > kafkalyzer_core::filter_expr::MAX_AST_DEPTH {
            anyhow::bail!("Filter AST exceeds maximum depth");
        }
        let node = nodes
            .get(idx as usize)
            .ok_or_else(|| anyhow::anyhow!("Invalid filter node index {idx}"))?;
        match node.kind {
            FilterNodeKind::And => {
                let children = node
                    .children
                    .iter()
                    .map(|&c| build(nodes, c, depth + 1))
                    .collect::<Result<Vec<_>>>()?;
                Ok(FilterNode::And(children))
            }
            FilterNodeKind::Or => {
                let children = node
                    .children
                    .iter()
                    .map(|&c| build(nodes, c, depth + 1))
                    .collect::<Result<Vec<_>>>()?;
                Ok(FilterNode::Or(children))
            }
            FilterNodeKind::Not => {
                let &child = node
                    .children
                    .first()
                    .ok_or_else(|| anyhow::anyhow!("NOT node missing child"))?;
                Ok(FilterNode::Not(Box::new(build(nodes, child, depth + 1)?)))
            }
            FilterNodeKind::Cond => {
                let cond = node
                    .condition
                    .as_ref()
                    .ok_or_else(|| anyhow::anyhow!("Cond node missing condition"))?;
                Ok(FilterNode::Cond(dto_to_cond(cond)?))
            }
        }
    }

    if nodes.is_empty() {
        anyhow::bail!("Filter node list cannot be empty");
    }
    build(nodes, 0, 0)
}

#[flutter_rust_bridge::frb(sync)]
pub fn parse_filter_expression(input: String) -> FilterParseResultDto {
    match parse(&input) {
        Ok(ast) => {
            let canonical = format_expr(&ast);
            match ast_to_flat_dtos(&ast) {
                Ok(nodes) => FilterParseResultDto {
                    ok: true,
                    nodes,
                    canonical: Some(canonical),
                    error: None,
                },
                Err(e) => FilterParseResultDto {
                    ok: false,
                    nodes: Vec::new(),
                    canonical: None,
                    error: Some(FilterErrorDto {
                        message: e.to_string(),
                        start_utf16: 0,
                        end_utf16: 0,
                    }),
                },
            }
        }
        Err(err) => {
            let (start_utf16, end_utf16) = err.span_utf16(&input);
            FilterParseResultDto {
                ok: false,
                nodes: Vec::new(),
                canonical: None,
                error: Some(FilterErrorDto {
                    message: err.message,
                    start_utf16: start_utf16 as u32,
                    end_utf16: end_utf16 as u32,
                }),
            }
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn format_filter_expression(nodes: Vec<FilterNodeDto>) -> Result<String> {
    let ast = flat_dtos_to_ast(&nodes)?;
    Ok(format_expr(&ast))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dto_roundtrip_and_utf16_error_offsets() {
        let input = "value.a = \"héllo\" OR (partition = 3 AND NOT value.b exists)";
        let parsed = parse_filter_expression(input.to_string());
        assert!(parsed.ok);
        let formatted = format_filter_expression(parsed.nodes.clone()).unwrap();
        assert_eq!(Some(formatted), parsed.canonical);

        let bad_input = "value.a = \"héllo😀\" AND unknownField = 1";
        let bad = parse_filter_expression(bad_input.to_string());
        assert!(!bad.ok);
        let err = bad.error.unwrap();
        let utf16_slice: Vec<u16> = bad_input
            .encode_utf16()
            .skip(err.start_utf16 as usize)
            .take((err.end_utf16 - err.start_utf16) as usize)
            .collect();
        assert_eq!(String::from_utf16(&utf16_slice).unwrap(), "unknownField");
    }
}
