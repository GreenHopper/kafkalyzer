use crate::api::kafka_types::ClusterProfile;
use kafkalyzer_core::schema_model as core;
use kafkalyzer_kafka::schema_registry as sr;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaCompatibilityResult {
    pub is_compatible: bool,
    pub messages: Vec<String>,
}

impl From<kafkalyzer_core::kafka_types::SchemaCompatibilityResult> for SchemaCompatibilityResult {
    fn from(r: kafkalyzer_core::kafka_types::SchemaCompatibilityResult) -> Self {
        Self {
            is_compatible: r.is_compatible,
            messages: r.messages,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchemaRegistryErrorKindDto {
    NotConfigured,
    InvalidUrl,
    Unauthorized,
    Forbidden,
    NotFound,
    Timeout,
    Unreachable,
    CertificateRejected,
    HttpStatus,
    InvalidResponse,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaRegistryErrorDto {
    pub kind: SchemaRegistryErrorKindDto,
    pub status: Option<u16>,
    pub registry_error_code: Option<i64>,
    pub detail: String,
}

impl std::fmt::Display for SchemaRegistryErrorDto {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.status {
            Some(s) => write!(f, "{:?} (HTTP {}): {}", self.kind, s, self.detail),
            None => write!(f, "{:?}: {}", self.kind, self.detail),
        }
    }
}

impl std::error::Error for SchemaRegistryErrorDto {}

impl From<sr::SchemaRegistryErrorKind> for SchemaRegistryErrorKindDto {
    fn from(k: sr::SchemaRegistryErrorKind) -> Self {
        match k {
            sr::SchemaRegistryErrorKind::NotConfigured => Self::NotConfigured,
            sr::SchemaRegistryErrorKind::InvalidUrl => Self::InvalidUrl,
            sr::SchemaRegistryErrorKind::Unauthorized => Self::Unauthorized,
            sr::SchemaRegistryErrorKind::Forbidden => Self::Forbidden,
            sr::SchemaRegistryErrorKind::NotFound => Self::NotFound,
            sr::SchemaRegistryErrorKind::Timeout => Self::Timeout,
            sr::SchemaRegistryErrorKind::Unreachable => Self::Unreachable,
            sr::SchemaRegistryErrorKind::CertificateRejected => Self::CertificateRejected,
            sr::SchemaRegistryErrorKind::HttpStatus => Self::HttpStatus,
            sr::SchemaRegistryErrorKind::InvalidResponse => Self::InvalidResponse,
        }
    }
}

impl From<sr::SchemaRegistryError> for SchemaRegistryErrorDto {
    fn from(e: sr::SchemaRegistryError) -> Self {
        Self {
            kind: e.kind.into(),
            status: e.status,
            registry_error_code: e.registry_error_code,
            detail: e.detail,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchemaKindDto {
    Avro,
    Protobuf,
    Json,
    Other,
}

impl From<&core::SchemaKind> for SchemaKindDto {
    fn from(k: &core::SchemaKind) -> Self {
        match k {
            core::SchemaKind::Avro => Self::Avro,
            core::SchemaKind::Protobuf => Self::Protobuf,
            core::SchemaKind::Json => Self::Json,
            core::SchemaKind::Other(_) => Self::Other,
        }
    }
}

fn other_type_name(k: &core::SchemaKind) -> Option<String> {
    match k {
        core::SchemaKind::Other(s) => Some(s.clone()),
        _ => None,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaReferenceDto {
    pub name: String,
    pub subject: String,
    pub version: i32,
}

impl From<core::SchemaReference> for SchemaReferenceDto {
    fn from(r: core::SchemaReference) -> Self {
        Self {
            name: r.name,
            subject: r.subject,
            version: r.version,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectSchemaDto {
    pub subject: String,
    pub version: i32,
    pub id: i32,
    pub schema_type: SchemaKindDto,
    pub other_schema_type: Option<String>,
    pub schema: String,
    pub references: Vec<SchemaReferenceDto>,
}

impl From<core::SubjectSchema> for SubjectSchemaDto {
    fn from(s: core::SubjectSchema) -> Self {
        let other_schema_type = other_type_name(&s.schema_type);
        let schema_type = (&s.schema_type).into();
        Self {
            subject: s.subject,
            version: s.version,
            id: s.id,
            schema_type,
            other_schema_type,
            schema: s.schema,
            references: s.references.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FieldNoteDto {
    Recursive,
    UnresolvedReference,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaFieldEntryDto {
    pub path: String,
    pub name: String,
    pub depth: u32,
    pub type_label: String,
    pub doc: Option<String>,
    pub optional: bool,
    pub repeated: bool,
    pub note: Option<FieldNoteDto>,
    pub unresolved_reference: Option<String>,
}

impl From<core::SchemaFieldEntry> for SchemaFieldEntryDto {
    fn from(e: core::SchemaFieldEntry) -> Self {
        let (note, unresolved_reference) = match e.note {
            Some(core::FieldNote::Recursive) => (Some(FieldNoteDto::Recursive), None),
            Some(core::FieldNote::UnresolvedReference(r)) => {
                (Some(FieldNoteDto::UnresolvedReference), Some(r))
            }
            None => (None, None),
        };
        Self {
            path: e.path,
            name: e.name,
            depth: e.depth,
            type_label: e.type_label,
            doc: e.doc,
            optional: e.optional,
            repeated: e.repeated,
            note,
            unresolved_reference,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaFieldModelDto {
    pub kind: SchemaKindDto,
    pub other_schema_type: Option<String>,
    pub root_name: Option<String>,
    pub messages: Vec<String>,
    pub fields: Vec<SchemaFieldEntryDto>,
    pub truncated: bool,
    pub unavailable_reason: Option<String>,
}

impl From<core::SchemaFieldModel> for SchemaFieldModelDto {
    fn from(m: core::SchemaFieldModel) -> Self {
        let other_schema_type = other_type_name(&m.kind);
        let kind = (&m.kind).into();
        Self {
            kind,
            other_schema_type,
            root_name: m.root_name,
            messages: m.messages,
            fields: m.fields.into_iter().map(Into::into).collect(),
            truncated: m.truncated,
            unavailable_reason: m.unavailable_reason,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectSchemaViewDto {
    pub schema: SubjectSchemaDto,
    pub fields: SchemaFieldModelDto,
}

impl From<sr::SubjectSchemaView> for SubjectSchemaViewDto {
    fn from(v: sr::SubjectSchemaView) -> Self {
        Self {
            schema: v.schema.into(),
            fields: v.fields.into(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicSideDto {
    Key,
    Value,
    None,
}

impl From<core::TopicSide> for TopicSideDto {
    fn from(s: core::TopicSide) -> Self {
        match s {
            core::TopicSide::Key => Self::Key,
            core::TopicSide::Value => Self::Value,
            core::TopicSide::None => Self::None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubjectAssociationDto {
    pub subject: String,
    pub topic: Option<String>,
    pub side: TopicSideDto,
    pub on_cluster: bool,
}

impl From<core::SubjectAssociation> for SubjectAssociationDto {
    fn from(a: core::SubjectAssociation) -> Self {
        Self {
            subject: a.subject,
            topic: a.topic,
            side: a.side.into(),
            on_cluster: a.on_cluster,
        }
    }
}

pub fn fetch_subjects(
    profile: ClusterProfile,
) -> std::result::Result<Vec<String>, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_subjects(domain_profile).map_err(Into::into)
}

pub fn fetch_schema(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> std::result::Result<String, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_schema(domain_profile, subject, version).map_err(Into::into)
}

pub fn fetch_schema_versions(
    profile: ClusterProfile,
    subject: String,
) -> std::result::Result<Vec<i32>, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_schema_versions(domain_profile, subject).map_err(Into::into)
}

pub fn check_schema_compatibility(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
    schema: String,
) -> std::result::Result<SchemaCompatibilityResult, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    let res = sr::check_schema_compatibility(domain_profile, subject, version, schema)?;
    Ok(SchemaCompatibilityResult::from(res))
}

pub fn fetch_subject_schema_view(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> std::result::Result<SubjectSchemaViewDto, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_subject_schema_view(domain_profile, subject, version)
        .map(Into::into)
        .map_err(Into::into)
}

pub fn fetch_global_compatibility(
    profile: ClusterProfile,
) -> std::result::Result<String, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_global_compatibility(domain_profile).map_err(Into::into)
}

pub fn fetch_subject_compatibility(
    profile: ClusterProfile,
    subject: String,
) -> std::result::Result<Option<String>, SchemaRegistryErrorDto> {
    let domain_profile = profile.to_domain();
    sr::fetch_subject_compatibility(domain_profile, subject).map_err(Into::into)
}

pub fn resolve_associated_topics_for_subject(
    subject: String,
    available_topics: Vec<String>,
) -> Vec<String> {
    sr::resolve_associated_topics_for_subject(&subject, &available_topics)
}

#[flutter_rust_bridge::frb(sync)]
pub fn associate_subjects(
    subjects: Vec<String>,
    topics: Vec<String>,
) -> Vec<SubjectAssociationDto> {
    core::associate_subjects(&subjects, &topics)
        .into_iter()
        .map(Into::into)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dto_mappings_and_associate_subjects_work() {
        let assocs = associate_subjects(
            vec!["orders-value".to_string(), "com.acme.Customer".to_string()],
            vec!["orders".to_string()],
        );
        assert_eq!(assocs.len(), 2);
        assert_eq!(assocs[0].topic.as_deref(), Some("orders"));
        assert_eq!(assocs[0].side, TopicSideDto::Value);
        assert!(assocs[0].on_cluster);
        assert_eq!(assocs[1].side, TopicSideDto::None);

        let err = SchemaRegistryErrorDto::from(sr::SchemaRegistryError {
            kind: sr::SchemaRegistryErrorKind::Unauthorized,
            status: Some(401),
            registry_error_code: Some(40100),
            detail: "bad credentials".to_string(),
        });
        assert_eq!(err.kind, SchemaRegistryErrorKindDto::Unauthorized);
        assert_eq!(err.status, Some(401));
    }
}
