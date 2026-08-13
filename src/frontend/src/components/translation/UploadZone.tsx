// EPUB Fordító – Feltöltő zóna (drag & drop)
import { useRef, useState, type DragEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { CloudUpload } from 'lucide-react';
import { uploadForTranslation } from '../../api/translations';
import { useUiStore } from '../../stores/uiStore';

interface Props {
  onUploaded?: () => void;
}

export function UploadZone({ onUploaded }: Props) {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);

  const handleFiles = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    const file = files[0];
    if (!file.name.toLowerCase().endsWith('.epub')) {
      addToast('error', 'Csak EPUB fájl tölthető fel!');
      return;
    }
    setUploading(true);
    try {
      await uploadForTranslation(file);
      addToast('success', `"${file.name}" feltöltve, fordítás elindult`);
      onUploaded?.();
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setUploading(false);
    }
  };

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragging(false);
    void handleFiles(e.dataTransfer.files);
  };

  return (
    <div
      onClick={() => inputRef.current?.click()}
      onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
      onDragLeave={() => setDragging(false)}
      onDrop={onDrop}
      className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-colors ${
        dragging ? 'border-accent-blue bg-accent-blue/5' : 'border-border-color'
      }`}
    >
      <CloudUpload className="w-10 h-10 text-accent-blue mx-auto mb-3" />
      <p className="font-medium text-text-primary mb-1">{t('dashboard.uploadTitle')}</p>
      <p className="text-text-secondary text-sm">{t('dashboard.uploadHint')}</p>
      {uploading && <p className="text-accent-yellow text-sm mt-2">{t('common.loading')}</p>}
      <input
        ref={inputRef}
        type="file"
        accept=".epub"
        className="hidden"
        onChange={(e) => void handleFiles(e.target.files)}
      />
    </div>
  );
}