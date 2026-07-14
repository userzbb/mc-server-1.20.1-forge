use std::io;
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Terminal,
};
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};

const PROJECT_DIR: &str = "/home/yuan/minecraft-server";

#[derive(Clone)]
struct Instance {
    uuid: String,
    nickname: String,
    has_data: bool,
    has_config: bool,
}

impl Instance {
    fn status(&self) -> &str {
        if self.has_data && self.has_config { "✅" }
        else if self.has_data { "⚠️" }
        else { "❌" }
    }
}

fn get_instances() -> Vec<Instance> {
    let config_dir = format!("{}/mcsm/daemon/data/InstanceConfig", PROJECT_DIR);
    let data_dir = format!("{}/mcsm/daemon/data/InstanceData", PROJECT_DIR);
    let mut instances = Vec::new();

    if let Ok(entries) = std::fs::read_dir(&config_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().map(|e| e == "json").unwrap_or(false) {
                let uuid = path.file_stem().unwrap().to_string_lossy().to_string();
                if uuid == "global0001" { continue; }
                if let Ok(content) = std::fs::read_to_string(&path) {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&content) {
                        let nickname = v.get("nickname").and_then(|n| n.as_str()).unwrap_or("?").to_string();
                        let has_data = std::path::Path::new(&format!("{}/{}", data_dir, uuid)).exists();
                        instances.push(Instance { uuid, nickname, has_data, has_config: true });
                    }
                }
            }
        }
    }

    if let Ok(entries) = std::fs::read_dir(&data_dir) {
        for entry in entries.flatten() {
            let uuid = entry.file_name().to_string_lossy().to_string();
            if uuid == "global0001" { continue; }
            if !instances.iter().any(|i| i.uuid == uuid) {
                instances.push(Instance { uuid, nickname: "未知".into(), has_data: true, has_config: false });
            }
        }
    }

    instances
}

fn get_backups() -> Vec<String> {
    let backup_dir = format!("{}/backups", PROJECT_DIR);
    let mut backups = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&backup_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.ends_with(".tar.gz") { backups.push(name); }
        }
    }
    backups.sort();
    backups.reverse();
    backups
}

fn main() -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut selected_tab = 0;
    let mut instance_state = ListState::default();
    instance_state.select(Some(0));
    let mut backup_state = ListState::default();
    backup_state.select(Some(0));
    let mut status_msg = String::from("Tab切换标签 | ↑↓选择 | Enter操作 | q退出");

    loop {
        let instances = get_instances();
        let backups = get_backups();

        terminal.draw(|f| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(3), Constraint::Min(0), Constraint::Length(3)])
                .split(f.area());

            let tabs = vec![
                Span::styled(" 实例 ", Style::default().fg(if selected_tab == 0 { Color::Yellow } else { Color::White })),
                Span::styled(" 备份 ", Style::default().fg(if selected_tab == 1 { Color::Yellow } else { Color::White })),
                Span::styled(" 操作 ", Style::default().fg(if selected_tab == 2 { Color::Yellow } else { Color::White })),
            ];
            let header = Paragraph::new(Line::from(tabs))
                .block(Block::default().borders(Borders::ALL).title("Minecraft TUI"));
            f.render_widget(header, chunks[0]);

            match selected_tab {
                0 => {
                    let items: Vec<ListItem> = instances.iter().map(|i| {
                        ListItem::new(Line::from(vec![
                            Span::raw(format!("{:<25}", i.nickname)),
                            Span::styled(format!("{} ", i.status()), Style::default().fg(
                                if i.has_data && i.has_config { Color::Green } else if i.has_data { Color::Yellow } else { Color::Red }
                            )),
                        ]))
                    }).collect();
                    let list = List::new(items)
                        .block(Block::default().borders(Borders::ALL).title("实例"))
                        .highlight_style(Style::default().fg(Color::Black).bg(Color::White));
                    f.render_stateful_widget(list, chunks[1], &mut instance_state);
                }
                1 => {
                    let items: Vec<ListItem> = backups.iter().map(|b| {
                        ListItem::new(Span::raw(b.clone()))
                    }).collect();
                    let list = List::new(items)
                        .block(Block::default().borders(Borders::ALL).title("备份"))
                        .highlight_style(Style::default().fg(Color::Black).bg(Color::White));
                    f.render_stateful_widget(list, chunks[1], &mut backup_state);
                }
                _ => {
                    let ops = vec![
                        ListItem::new("  1. 清理孤儿实例"),
                        ListItem::new("  2. 重启所有服务"),
                        ListItem::new("  3. 退出"),
                    ];
                    let list = List::new(ops)
                        .block(Block::default().borders(Borders::ALL).title("操作"));
                    f.render_widget(list, chunks[1]);
                }
            }

            let status = Paragraph::new(status_msg.clone())
                .block(Block::default().borders(Borders::ALL));
            f.render_widget(status, chunks[2]);
        })?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Tab => { selected_tab = (selected_tab + 1) % 3; }
                    KeyCode::Up => {
                        let state = if selected_tab == 0 { &mut instance_state } else { &mut backup_state };
                        if let Some(i) = state.selected() {
                            state.select(Some(i.saturating_sub(1)));
                        }
                    }
                    KeyCode::Down => {
                        let state = if selected_tab == 0 { &mut instance_state } else { &mut backup_state };
                        let len = if selected_tab == 0 { instances.len() } else { backups.len() };
                        if let Some(i) = state.selected() {
                            state.select(Some((i + 1).min(len.saturating_sub(1))));
                        }
                    }
                    KeyCode::Enter => {
                        if selected_tab == 0 {
                            if let Some(i) = instance_state.selected() {
                                if let Some(inst) = instances.get(i) {
                                    status_msg = format!("选中: {} ({})", inst.nickname, inst.uuid);
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    Ok(())
}
