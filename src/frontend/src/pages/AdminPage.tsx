// EPUB Fordító – Admin oldal
// Felhasználók listája, log néző, rendszer monitor + teljes CRUD.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Shield, Users, FileText, Activity, Plus, Pencil, Trash2 } from 'lucide-react';
import { apiGet, apiPost, apiPut, apiDelete } from '../api/client';
import { useUiStore } from '../stores/uiStore';

interface AdminUser {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  tokens: number;
  is_admin: boolean;
  created_at: string | null;
}

interface UserForm {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  tokens: number;
  is_admin: boolean;
}

const emptyForm: UserForm = { email: '', password: '', first_name: '', last_name: '', tokens: 5, is_admin: false };

export function AdminPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const addToast = useUiStore((s) => s.addToast);
  const [tab, setTab] = useState<'users' | 'logs' | 'system'>('users');
  const [editing, setEditing] = useState<AdminUser | null>(null);
  const [form, setForm] = useState<UserForm>(emptyForm);

  const { data: users, isLoading: usersLoading } = useQuery<AdminUser[]>({
    queryKey: ['admin-users'],
    queryFn: async () => {
      const d = await apiGet<{ users: AdminUser[] }>('/api/admin/users');
      return d.users;
    },
    enabled: tab === 'users',
  });

  const { data: logs, isLoading: logsLoading } = useQuery<string>({
    queryKey: ['admin-logs'],
    queryFn: async () => {
      const d = await apiGet<{ log_content: string }>('/api/admin/logs?type=app&lines=100');
      return d.log_content;
    },
    enabled: tab === 'logs',
  });

  const { data: sysinfo } = useQuery<{
    cpu: { percent: number; cores: number };
    memory: { total_gb: number; used_gb: number; percent: number };
    disk: { total_gb: number; free_gb: number; percent: number };
  }>({
    queryKey: ['admin-system'],
    queryFn: () => apiGet('/api/system/monitor'),
    enabled: tab === 'system',
  });

  const invalidateUsers = () => queryClient.invalidateQueries({ queryKey: ['admin-users'] });

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
  };

  const openEdit = (u: AdminUser) => {
    setEditing(u);
    setForm({
      email: u.email,
      password: '',
      first_name: u.first_name || '',
      last_name: u.last_name || '',
      tokens: u.tokens,
      is_admin: u.is_admin,
    });
  };

  const handleSave = async () => {
    try {
      if (editing) {
        await apiPut(`/api/admin/users/${editing.id}`, form);
        addToast('success', 'Felhasználó módosítva');
      } else {
        await apiPost('/api/admin/users', form);
        addToast('success', 'Felhasználó létrehozva');
      }
      setEditing(null);
      setForm(emptyForm);
      void invalidateUsers();
    } catch (e) {
      addToast('error', (e as Error).message || t('common.errorOccurred'));
    }
  };

  const handleDelete = async (u: AdminUser) => {
    if (!window.confirm(`Biztosan törlöd a(z) ${u.email} felhasználót?`)) return;
    try {
      await apiDelete(`/api/admin/users/${u.id}`);
      addToast('success', 'Felhasználó törölve');
      void invalidateUsers();
    } catch (e) {
      addToast('error', (e as Error).message || t('common.errorOccurred'));
    }
  };

  const tabs = [
    { key: 'users' as const, label: 'Felhasználók', icon: Users },
    { key: 'logs' as const, label: 'Logok', icon: FileText },
    { key: 'system' as const, label: 'Rendszer', icon: Activity },
  ];

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
        <Shield className="w-6 h-6" />
        {t('nav.admin')}
      </h1>

      <div className="flex gap-2">
        {tabs.map(({ key, label, icon: Icon }) => (
          <button key={key} onClick={() => setTab(key)} className={`btn ${tab === key ? 'btn-primary' : 'btn-outline'}`}>
            <Icon className="w-4 h-4" /> {label}
          </button>
        ))}
      </div>

      {tab === 'users' && (
        <div className="space-y-3">
          <button onClick={openCreate} className="btn-primary">
            <Plus className="w-4 h-4" /> Új felhasználó
          </button>

          {editing !== null || (form.email !== '' && form.password !== '' && editing === null) ? (
            <div className="card p-4 space-y-3">
              <h2 className="font-semibold text-text-primary">
                {editing ? 'Felhasználó szerkesztése' : 'Új felhasználó'}
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <input className="form-input" placeholder="Vezetéknév" value={form.last_name}
                  onChange={(e) => setForm({ ...form, last_name: e.target.value })} />
                <input className="form-input" placeholder="Keresztnév" value={form.first_name}
                  onChange={(e) => setForm({ ...form, first_name: e.target.value })} />
                <input className="form-input" placeholder="Email" type="email" value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })} />
                <input className="form-input" placeholder="Jelszó" type="password" value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })} />
                <input className="form-input" placeholder="Tokenek" type="number" value={form.tokens}
                  onChange={(e) => setForm({ ...form, tokens: Number(e.target.value) })} />
                <label className="flex items-center gap-2 text-sm text-text-primary">
                  <input type="checkbox" checked={form.is_admin}
                    onChange={(e) => setForm({ ...form, is_admin: e.target.checked })} />
                  Admin
                </label>
              </div>
              <div className="flex gap-2">
                <button onClick={() => void handleSave()} className="btn-primary">
                  Mentés
                </button>
                <button onClick={() => { setEditing(null); setForm(emptyForm); }} className="btn-outline">
                  Mégse
                </button>
              </div>
            </div>
          ) : null}

          <div className="card card-body">
            {usersLoading ? (
              <div className="skeleton h-40" />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-left text-text-secondary border-b border-border-color">
                      <th className="py-2 pr-4">Név</th>
                      <th className="py-2 pr-4">Email</th>
                      <th className="py-2 pr-4">Token</th>
                      <th className="py-2 pr-4">Szerep</th>
                      <th className="py-2">Műveletek</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users?.map((u) => (
                      <tr key={u.id} className="border-b border-border-color/50">
                        <td className="py-2 pr-4 text-text-primary">{u.last_name} {u.first_name}</td>
                        <td className="py-2 pr-4 text-text-secondary">{u.email}</td>
                        <td className="py-2 pr-4">{u.tokens}</td>
                        <td className="py-2 pr-4">
                          <span className={`badge ${u.is_admin ? 'bg-accent-purple/15 text-accent-purple' : 'bg-bg-secondary text-text-secondary'}`}>
                            {u.is_admin ? 'Admin' : 'Felhasználó'}
                          </span>
                        </td>
                        <td className="py-2">
                          <div className="flex gap-1">
                            <button onClick={() => openEdit(u)} className="btn-ghost min-w-[32px] min-h-[32px] p-1" title="Szerkesztés">
                              <Pencil className="w-4 h-4" />
                            </button>
                            <button onClick={() => void handleDelete(u)} className="btn-ghost min-w-[32px] min-h-[32px] p-1 text-accent-red" title="Törlés">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'logs' && (
        <div className="card card-body">
          {logsLoading ? (
            <div className="skeleton h-40" />
          ) : (
            <pre className="text-xs font-mono text-text-secondary whitespace-pre-wrap max-h-[400px] overflow-y-auto">
              {logs || '(Nincs log tartalom)'}
            </pre>
          )}
        </div>
      )}

      {tab === 'system' && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="card card-body text-center">
            <div className="text-3xl font-bold text-accent-blue">{sysinfo?.cpu.percent ?? '-'}%</div>
            <div className="text-xs text-text-secondary mt-1">CPU ({sysinfo?.cpu.cores ?? '-'} mag)</div>
          </div>
          <div className="card card-body text-center">
            <div className="text-3xl font-bold text-accent-green">{sysinfo?.memory.percent ?? '-'}%</div>
            <div className="text-xs text-text-secondary mt-1">
              RAM {sysinfo?.memory.used_gb ?? '-'}/{sysinfo?.memory.total_gb ?? '-'} GB
            </div>
          </div>
          <div className="card card-body text-center">
            <div className="text-3xl font-bold text-accent-yellow">{sysinfo?.disk.percent ?? '-'}%</div>
            <div className="text-xs text-text-secondary mt-1">
              Lemez {sysinfo?.disk.free_gb ?? '-'} GB szabad
            </div>
          </div>
        </div>
      )}
    </div>
  );
}