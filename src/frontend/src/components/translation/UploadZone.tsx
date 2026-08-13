// EPUB Fordító – Feltöltő zóna (drag & drop)
// Bővítve: modellválasztás + kontextus-könyv választás a fordítás előtt.
import { useRef, useState, useEffect, type DragEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { CloudUpload, Cpu, BookOpen } from 'lucide-react';
import { uploadForTranslation } from '../../api/translations';
import { fetchModels } from '../../api/settings';
import { fetchLibraryBooks } from '../../api/library';
import type { ModelInfo, RemoteModel, Book } from '../../api/types';
import { useUiStore } from '../../stores/uiStore';

interface Props {
  onUploaded?: () => void;
}

export function UploadZone({ onUploaded }: Props) {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);

  // Modell / kontextus beállítások
  const [source, setSource] = useState<'local' | 'remote'>('local');
  const [selectedModel, setSelectedModel] = useState('');
  const [selectedBookIds, setSelectedBookIds] = useState<number[]>([]);
  const [showOptions, setShowOptions] = useState(false);

  // Elérhető modellek + könyvtári könyvek
  const [models, setModels] = useState<ModelInfo[]>([]);
  const [remoteModels, setRemoteModels] = useState<RemoteModel[]>([]);
  const [books, setBooks] = useState<Book[]>([]);

  useEffect(() => {
    void fetchModels()
      .then((d) => {
        const localNames = d.models.map((m) => ({ name: m.name ?? '' }));
        setModels(localNames);
        setRemoteModels(d.remote_models ?? []);
      })
      .catch(() => {});
    void fetchLibraryBooks()
      .then(setBooks)
      .catch(() => {});
  }, []);

  const handleFiles = (files: FileList | null) => {
    if (!files || files.length === 0) return;
    const f = files[0];
    if (!f.name.toLowerCase().endsWith('.epub')) {
      addToast('error', 'Csak EPUB fájl tölthető fel!');
      return;
    }
    setFile(f);
  };

  const handleUpload = async () => {
    if (!file) {
      // Fájl még nincs kiválasztva (kattintás) – nyitva hagyjuk a fájlválasztót
      inputRef.current?.click();
      return;
    }
    setUploading(true);
    try {
      await uploadForTranslation(file, {
        modelSource: source,
        selectedModel: source === 'remote' ? selectedModel : undefined,
        referenceIds: selectedBookIds,
      });
      addToast('success', `"${file.name}" feltöltve, fordítás elindult`);
      setFile(null);
      setSelectedBookIds([]);
      setShowOptions(false);
      onUploaded?.();
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setUploading(false);
    }
  };

  const toggleBook = (id: number) => {
    setSelectedBookIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  };

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragging(false);
    handleFiles(e.dataTransfer.files);
  };

  return (
    <div className="space-y-3">
      <div
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={onDrop}
        className={`border-2 border-dashed rounded-2xl p-6 text-center cursor-pointer transition-colors ${
          dragging ? 'border-accent-blue bg-accent-blue/5' : 'border-border-color'
        }`}
      >
        <CloudUpload className="w-10 h-10 text-accent-blue mx-auto mb-3" />
        {file ? (
          <>
            <p className="font-medium text-text-primary mb-1">{file.name}</p>
            <p className="text-text-secondary text-sm">{(file.size / 1024 / 1024).toFixed(2)} MB</p>
          </>
        ) : (
          <>
            <p className="font-medium text-text-primary mb-1">{t('dashboard.uploadTitle')}</p>
            <p className="text-text-secondary text-sm">{t('dashboard.uploadHint')}</p>
          </>
        )}
        <input
          ref={inputRef}
          type="file"
          accept=".epub"
          className="hidden"
          onChange={(e) => handleFiles(e.target.files)}
        />
      </div>

      {/* Beállítási rész */}
      {file && (
        <div className="card p-4 space-y-3">
          <button
            onClick={() => setShowOptions((v) => !v)}
            className="btn-outline w-full flex items-center justify-center gap-2"
          >
            <Cpu className="w-4 h-4" />
            {showOptions ? 'Beállítások elrejtése' : 'Modell és kontextus kiválasztása'}
          </button>

          {showOptions && (
            <>
              {/* Modellforrás */}
              <div className="flex gap-2">
                <button
                  onClick={() => setSource('local')}
                  className={`btn flex-1 ${source === 'local' ? 'btn-primary' : 'btn-outline'}`}
                >
                  🖥️ Helyi
                </button>
                <button
                  onClick={() => setSource('remote')}
                  className={`btn flex-1 ${source === 'remote' ? 'btn-primary' : 'btn-outline'}`}
                >
                  ☁️ DeepSeek Pro
                </button>
              </div>

              {/* Modell lista */}
              <div className="max-h-40 overflow-y-auto space-y-1">
                {source === 'local'
                  ? models.map((m) => (
                      <label key={m.name} className="flex items-center gap-2 text-sm text-text-primary py-1">
                        <input
                          type="radio"
                          name="model"
                          checked={selectedModel === m.name}
                          onChange={() => setSelectedModel(m.name)}
                        />
                        {m.name}
                      </label>
                    ))
                  : remoteModels.map((m) => (
                      <label key={m.id} className="flex items-center gap-2 text-sm text-text-primary py-1">
                        <input
                          type="radio"
                          name="model"
                          checked={selectedModel === m.id}
                          onChange={() => setSelectedModel(m.id)}
                        />
                        {m.name}
                      </label>
                    ))}
                {source === 'local' && models.length === 0 && (
                  <p className="text-xs text-text-secondary">Nincs elérhető helyi modell.</p>
                )}
              </div>

              {/* Kontextus könyvek */}
              <div className="flex items-center gap-2 text-text-primary pt-2">
                <BookOpen className="w-4 h-4" />
                <span className="font-medium">Kontextus könyvek</span>
              </div>
              <div className="max-h-40 overflow-y-auto space-y-1">
                {books.map((b) => (
                  <label key={b.id} className="flex items-center gap-2 text-sm text-text-primary py-1">
                    <input
                      type="checkbox"
                      checked={selectedBookIds.includes(b.id)}
                      onChange={() => toggleBook(b.id)}
                    />
                    <span className="truncate">{b.title || b.filename}</span>
                  </label>
                ))}
                {books.length === 0 && (
                  <p className="text-xs text-text-secondary">Nincs könyv a könyvtárban.</p>
                )}
              </div>
            </>
          )}

          <button
            onClick={() => void handleUpload()}
            disabled={uploading}
            className="btn-primary w-full"
          >
            {uploading ? t('common.loading') : 'Fordítás indítása'}
          </button>
        </div>
      )}
    </div>
  );
}