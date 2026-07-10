import SwiftUI

/// Manage custom word replacements and spoken snippets.
///
/// A rule rewrites the trigger phrase in the final transcript with the
/// replacement text — say "my email" and get your address, or fix a term the
/// model keeps mishearing. Rules run fully offline for every engine.
struct DictionaryView: View {
    @StateObject private var dictionary = DictionaryService.shared
    @State private var editorEntry: DictionaryEntry?
    @State private var isPresentingEditor = false
    @State private var entryPendingDeletion: DictionaryEntry?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                explainer

                if dictionary.entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(dictionary.entries) { entry in
                            DictionaryRuleCard(
                                entry: entry,
                                onToggle: { dictionary.setEnabled($0, for: entry.id) },
                                onEdit: { present(entry) },
                                onDelete: { entryPendingDeletion = entry }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            DictionaryEntryEditor(entry: editorEntry) { result in
                if dictionary.entries.contains(where: { $0.id == result.id }) {
                    dictionary.update(result)
                } else {
                    dictionary.addEntry(
                        trigger: result.trigger,
                        replacement: result.replacement,
                        matchWholeWord: result.matchWholeWord
                    )
                }
            }
        }
        .alert(
            "Delete Rule?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            presenting: entryPendingDeletion
        ) { entry in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dictionary.delete(id: entry.id)
                entryPendingDeletion = nil
            }
        } message: { entry in
            Text("“\(entry.trimmedTrigger)” will no longer be replaced.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dictionary")
                    .font(Typography.displayLarge)
                    .foregroundStyle(Color.textPrimary)

                if !dictionary.entries.isEmpty {
                    Text("\(dictionary.entries.count) rule\(dictionary.entries.count == 1 ? "" : "s")")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            Button(action: { present(nil) }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add Rule")
                }
                .font(Typography.labelMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Explainer

    private var explainer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentBlue)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Turn what you say into the text you want")
                    .font(Typography.labelLarge)
                    .foregroundStyle(Color.textPrimary)
                Text(
                    "Say a trigger like “my email” and SpeakType inserts your real address. Or fix a name the model keeps mishearing. Everything runs offline on your Mac."
                )
                .font(Typography.captionSmall)
                .foregroundStyle(Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.accentBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Color.textMuted.opacity(0.4))

            VStack(spacing: 8) {
                Text("No rules yet")
                    .font(Typography.displaySmall)
                    .foregroundStyle(Color.textPrimary)

                Text("Add your first rule to replace a spoken phrase with any text.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { present(nil) }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add Rule")
                }
                .font(Typography.labelMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func present(_ entry: DictionaryEntry?) {
        editorEntry = entry
        isPresentingEditor = true
    }
}

// MARK: - Rule Card

private struct DictionaryRuleCard: View {
    let entry: DictionaryEntry
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    private var replacementDisplay: String {
        entry.replacement.isEmpty ? "(deleted)" : entry.replacement
    }

    var body: some View {
        HStack(spacing: 16) {
            // Trigger → replacement
            HStack(spacing: 12) {
                Text(entry.trimmedTrigger)
                    .font(Typography.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textMuted)

                Text(replacementDisplay)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(entry.replacement.isEmpty ? Color.textMuted : Color.textSecondary)
                    .lineLimit(1)
                    .italic(entry.replacement.isEmpty)
            }
            .opacity(entry.isEnabled ? 1 : 0.45)

            Spacer(minLength: 12)

            // Attribute chips
            HStack(spacing: 6) {
                if !entry.matchWholeWord {
                    RuleChip(text: "partial")
                }
            }
            .opacity(entry.isEnabled ? 1 : 0.45)

            // Actions (revealed on hover)
            HStack(spacing: 4) {
                if isHovered {
                    IconButton(systemName: "pencil", action: onEdit)
                    IconButton(systemName: "trash", action: onDelete)
                }
            }
            .frame(width: isHovered ? 56 : 0, alignment: .trailing)
            .clipped()

            Toggle("", isOn: Binding(get: { entry.isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.border : Color.border.opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

private struct RuleChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typography.captionSmall)
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.bgHover)
            .clipShape(Capsule())
    }
}

private struct IconButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(isHovered ? Color.textPrimary : Color.textMuted)
                .frame(width: 24, height: 24)
                .background(isHovered ? Color.bgHover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Editor Sheet

private struct DictionaryEntryEditor: View {
    /// nil when adding a brand-new rule.
    let entry: DictionaryEntry?
    let onSave: (DictionaryEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var trigger: String
    @State private var replacement: String
    @State private var matchWholeWord: Bool

    init(entry: DictionaryEntry?, onSave: @escaping (DictionaryEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _trigger = State(initialValue: entry?.trigger ?? "")
        _replacement = State(initialValue: entry?.replacement ?? "")
        _matchWholeWord = State(initialValue: entry?.matchWholeWord ?? true)
    }

    private var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry == nil ? "New Rule" : "Edit Rule")
                .font(Typography.displaySmall)
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {
                field(
                    title: "When I say",
                    subtitle: "The word or phrase to listen for"
                ) {
                    TextField("", text: $trigger, prompt: Text("my email"))
                        .textFieldStyle(.plain)
                }

                field(
                    title: "Replace with",
                    subtitle: "Any text to insert. Leave empty to remove the phrase."
                ) {
                    TextField(
                        "", text: $replacement, prompt: Text("john.doe@example.com"),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                }

                Divider()

                Toggle(isOn: $matchWholeWord) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Match whole words only")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color.textPrimary)
                        Text("Won't fire inside longer words.")
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .toggleStyle(.switch)
            }

            Spacer(minLength: 24)

            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(Typography.labelMedium)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Save") { save() }
                    .buttonStyle(.plain)
                    .font(Typography.labelMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(isValid ? Color.accentBlue : Color.accentBlue.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(!isValid)
            }
        }
        .padding(28)
        .frame(width: 440)
        .background(Color.bgContent)
    }

    @ViewBuilder
    private func field<Content: View>(
        title: String, subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.labelLarge)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
            }

            ZStack(alignment: .topLeading) {
                content()
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(Color.bgHover)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.border.opacity(0.6), lineWidth: 1)
            )
        }
    }

    private func save() {
        guard isValid else { return }
        var result = entry ?? DictionaryEntry(trigger: "", replacement: "")
        result.trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        result.replacement = replacement
        result.matchWholeWord = matchWholeWord
        onSave(result)
        dismiss()
    }
}
