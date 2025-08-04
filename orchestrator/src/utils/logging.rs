use tracing::{Event, Subscriber, Level};
use tracing_error::ErrorLayer;
use tracing_subscriber::{
    fmt::{self, FmtContext, FormatEvent, FormatFields},
    prelude::*,
    registry::LookupSpan,
    EnvFilter, Registry,
};
use serde_json::Value;

/// A custom formatter to include service/job type in logs.
struct ServiceOrientedFormatter;

impl<S, N> FormatEvent<S, N> for ServiceOrientedFormatter
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
{
    fn format_event(&self, ctx: &FmtContext<'_, S, N>, mut writer: fmt::format::Writer<'_>, event: &Event<'_>) -> std::fmt::Result {
        let meta = event.metadata();
        let timestamp = chrono::Utc::now().format("[%Y-%m-%d %H:%M:%S]");

        // Timestamp and Level
        write!(writer, "{} {} ", timestamp, meta.level())?;

        // Service Name from span
        let mut service_name = String::new();
        if let Some(span) = ctx.lookup_current() {
            let extensions = span.extensions();
            if let Some(fields) = extensions.get::<fmt::FormattedFields<N>>() {
                // Fields are stored as a string, e.g., "q=\"ProvingJobProcessing\""
                // This is a bit of a hack, but it's the most straightforward way to get the data.
                let fields_str = fields.to_string();
                let parts: Vec<&str> = fields_str.split('=').collect();
                if parts.len() == 2 {
                    let key = parts[0].trim();
                    if key == "q" || key == "job_type" {
                        let value = parts[1].trim_matches('"').to_string();
                        service_name = format!("[{}]", value);
                    }
                }
            }
        }

        if service_name.is_empty() {
             write!(writer, "[{}] ", meta.target())?;
        } else {
             write!(writer, "{} ", service_name)?;
        }

        // Message
        let mut visitor = MessageVisitor::default();
        event.record(&mut visitor);
        write!(writer, "{}", visitor.message)?;

        writeln!(writer)
    }
}

#[derive(Default)]
struct MessageVisitor {
    message: String,
}

impl tracing::field::Visit for MessageVisitor {
    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        if field.name() == "message" {
            self.message = format!("{:?}", value);
        }
    }
}

/// Initialize the tracing subscriber.
pub fn init_logging() {
    color_eyre::install().expect("Unable to install color_eyre");

    let env_filter = EnvFilter::builder()
        .with_default_directive(Level::INFO.into())
        .parse(std::env::var("RUST_LOG").unwrap_or_else(|_| "orchestrator=info,tower_http=info".to_string()))
        .expect("Invalid filter directive and Logger control");

    let fmt_layer = fmt::layer()
        .event_format(ServiceOrientedFormatter)
        .with_ansi(false);

    let subscriber = Registry::default()
        .with(env_filter)
        .with(fmt_layer)
        .with(ErrorLayer::default());

    tracing::subscriber::set_global_default(subscriber).expect("Failed to set global default subscriber");
}
