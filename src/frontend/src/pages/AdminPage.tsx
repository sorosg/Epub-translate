// EPUB Fordító – Admin oldal (6. fázis)
// Felhasználók listája, log néző, rendszer monitor.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Shield, Users, FileText, Activity } from 'lucide-react';
import { apiGet } from '../api/client';

interface AdminUser {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  tokens: number;
  is_admin: boolean;
  created_at: string | null;
}

export function AdminPage() {
  const { t } = useTranslation();
  const [tab, setTab] = useState<'users' | 'logs' | 'system'>('users');

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

      {/* Fül választó */}
      <div className="flex gap-2">
        {tabs.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`btn ${tab === key ? 'btn-primary' : 'btn-outline'}`}
          >
            <Icon className="w-4 h-4" /> {label}
          </button>
        ))}
      </div>

      {/* Felhasználók */}
      {tab === 'users' && (
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
                    <th className="py-2">Szerep</th>
                  </tr>
                </thead>
                <tbody>
                  {users?.map((u) => (
                    <tr key={u.id} className="border-b border-border-color/50">
                      <td className="py-2 pr-4 text-text-primary">
                        {u.last_name} {u.first_name}
                      </td>
                      <td className="py-2 pr-4 text-text-secondary">{u.email}</td>
                      <td className="py-2 pr-4">{u.tokens}</td>
                      <td className="py-2">
                        <span className={`badge ${u.is_admin ? 'bg-accent-purple/15 text-accent-purple' : 'bg-bg-secondary text-text-secondary'}`}>
                          {u.is_admin ? 'Admin' : 'Felhasználó'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Logok */}
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

      {/* Rendszer */}
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