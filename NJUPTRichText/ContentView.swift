//
//  ContentView.swift
//  NJUPTRichText
//
//  Created by 谢国华 on 2025/4/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NoteViewModel()
    @State private var newNoteTitle = "新建笔记"
    @State private var newNoteContent = ""
    @State private var isShowingNewNoteSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.notes.enumerated()), id: \.element.id) { index, note in
                    NavigationLink(destination: NoteDetailView(viewModel: viewModel, noteIndex: index)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.title)
                                .font(.headline)
                            Text(note.content)
                                .lineLimit(2)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(note.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteNote)
            }
            .navigationTitle("我的笔记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        newNoteTitle = "新建笔记"
                        newNoteContent = ""
                        isShowingNewNoteSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewNoteSheet) {
                NavigationView {
                    VStack(spacing: 16) {
                        TextField("笔记标题", text: $newNoteTitle)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextEditor(text: $newNoteContent)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top)
                    .navigationBarItems(
                        leading: Button("取消") {
                            isShowingNewNoteSheet = false
                        },
                        trailing: Button("保存") {
                            if !newNoteContent.isEmpty {
                                viewModel.addNote(title: newNoteTitle, content: newNoteContent)
                                isShowingNewNoteSheet = false
                            }
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
