import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            BlockLibraryView()
        } detail: {
            BuildWorkspaceView()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Picker("Mood", selection: $store.mood) {
                    ForEach(BuildMood.allCases) { mood in
                        Text(mood.rawValue).tag(mood)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task { await store.generateFromPrompt() }
                } label: {
                    Label("Generate Prompt", systemImage: "sparkles")
                }
                .disabled(store.isGeneratingAI)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.exportSummary(), forType: .string)
                } label: {
                    Label("Copy List", systemImage: "doc.on.doc")
                }
                .disabled(store.buildBlocks.isEmpty)
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pokopia Builder")
                    .font(.title2.weight(.bold))
                Text("\(store.blocks.count) local items and blocks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)

            TextField("Search blocks", text: $store.searchText)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 6) {
                ForEach(BlockKind.allCases) { kind in
                    Button {
                        store.selectedKind = kind
                    } label: {
                        Label(kind.rawValue, systemImage: kind.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: store.selectedKind == kind))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Prompt Generator", systemImage: "wand.and.stars")
                    .font(.headline)

                Picker("Generator", selection: $store.generatorProvider) {
                    ForEach(BuildGeneratorProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: $store.promptText)
                    .font(.callout)
                    .frame(minHeight: 92)
                    .scrollContentBackground(.hidden)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }

                HStack {
                    if store.generatorProvider == .local {
                        TextField("Ollama model", text: $store.model)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("OpenAI model", text: $store.openAIModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        Task { await store.generateFromPrompt() }
                    } label: {
                        if store.isGeneratingAI {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                    }
                    .disabled(store.isGeneratingAI)
                    .help("Generate from prompt")
                }

                if store.generatorProvider == .openAI {
                    SecureField("OpenAI API key", text: $store.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            store.saveAPIKey()
                        }
                }

                Button {
                    store.randomize()
                } label: {
                    Label("Offline Random", systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }

                if let status = store.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    store.chooseModelFolder()
                } label: {
                    Label("Choose Model Folder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }

                Text(store.modelFolderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Link(destination: PokopiaData.sourceURL) {
                Label("Open Game8 Blocks", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(minWidth: 230)
    }
}

private struct BlockLibraryView: View {
    @EnvironmentObject private var store: PlannerStore

    private let columns = [
        GridItem(.adaptive(minimum: 172, maximum: 240), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(store.filteredBlocks) { block in
                    BlockCard(block: block, isSelected: store.selectedBlock == block) {
                        store.selectedBlock = block
                    } addAction: {
                        store.add(block)
                    }
                    .draggable(block.id)
                }
            }
            .padding(18)
        }
        .navigationTitle(store.selectedKind.rawValue)
    }
}

private struct BuildWorkspaceView: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let generatedIdea = store.generatedIdea {
                        IdeaPanel(idea: generatedIdea)
                    }

                    BuildSceneView()
                        .environmentObject(store)

                    if store.buildBlocks.isEmpty {
                        EmptyBuildView()
                            .padding(.top, 40)
                    } else {
                        BuildGridView(blocks: store.buildBlocks)
                        MaterialsList()
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Label("\(store.totalBlocks) planned blocks", systemImage: "shippingbox")
                Spacer()
                Button("Clear") {
                    store.clearBuild()
                }
                .disabled(store.buildBlocks.isEmpty)
            }
            .padding(14)
            .background(.bar)
        }
        .navigationTitle("Build Plan")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.generatedIdea?.name ?? "Custom Build")
                    .font(.system(size: 30, weight: .bold))
                Text("Drag items into the 3D scene, tune quantities, or generate a prompt-based build plan.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await store.generateFromPrompt() }
            } label: {
                Label("Generate", systemImage: "sparkles")
            }
            .controlSize(.large)
            .disabled(store.isGeneratingAI)
        }
    }
}

private struct BlockCard: View {
    var block: PokopiaBlock
    var isSelected: Bool
    var selectAction: () -> Void
    var addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: selectAction) {
                VStack(alignment: .leading, spacing: 10) {
                    BlockThumbnail(block: block)
                        .frame(height: 92)

                    Text(block.name)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(block.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(minHeight: 48, alignment: .top)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Label(block.category, systemImage: block.kind.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: addAction) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Add to build")
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? block.tint : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        }
    }
}

private struct BlockThumbnail: View {
    var block: PokopiaBlock

    var body: some View {
        ZStack {
            if let imagePath = block.imagePath, let image = NSImage(contentsOfFile: imagePath) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.82))
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(10)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(block.tint.gradient.opacity(0.72))
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.2), lineWidth: 1)

                VStack(spacing: 8) {
                    Image(systemName: block.kind.symbol)
                        .font(.system(size: 30, weight: .semibold))
                    Text(block.name.prefix(2).uppercased())
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .shadow(radius: 2)
            }
        }
    }
}

private struct IdeaPanel: View {
    var idea: BuildIdea

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(idea.mood.rawValue, systemImage: "sparkles")
                Spacer()
                Label(idea.footprint, systemImage: "ruler")
            }
            .font(.headline)

            ForEach(idea.notes, id: \.self) { note in
                Label(note, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BuildGridView: View {
    var blocks: [PlacedBlock]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 6), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(blocks.prefix(36)) { placed in
                BlockThumbnail(block: placed.block)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(placed.count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
            }
        }
    }
}

private struct MaterialsList: View {
    @EnvironmentObject private var store: PlannerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Materials")
                .font(.title3.weight(.semibold))

            ForEach(store.buildBlocks) { placed in
                HStack(spacing: 12) {
                    BlockThumbnail(block: placed.block)
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(placed.block.name)
                            .font(.headline)
                        Text(detailLine(for: placed.block))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper(value: Binding(
                        get: { placed.count },
                        set: { store.update(placed, count: $0) }
                    ), in: 1...999) {
                        Text("\(placed.count)")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }

                    Button {
                        store.remove(placed)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
                .padding(10)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func detailLine(for block: PokopiaBlock) -> String {
        if !block.recipeIngredients.isEmpty {
            return "Recipe: " + block.recipeIngredients.prefix(4).joined(separator: ", ")
        }
        if let source = block.unlockSources.first {
            return source
        }
        return block.category
    }
}

private struct EmptyBuildView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No blocks planned yet")
                .font(.title3.weight(.semibold))
            Text("Pick blocks from the library or roll a random build idea.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
