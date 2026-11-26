// Browser-side Supabase adapter for the Open Doors Dispatch Center.
// Inject a Supabase client created by the app's approved config/build layer.
// Never initialize this with a service_role/secret key.
export function createDispatchBackend(supabase) {
  if (!supabase || typeof supabase.from !== "function" || !supabase.auth) {
    throw new TypeError("A configured Supabase client is required.");
  }

  async function requireUser() {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data?.user) throw new Error("Please sign in to continue.");
    return data.user;
  }

  async function run(query) {
    const { data, error } = await query;
    if (error) throw error;
    return data;
  }

  return {
    auth: {
      async signUp(email, password) {
        return run(supabase.auth.signUp({ email, password }));
      },
      async signIn(email, password) {
        return run(supabase.auth.signInWithPassword({ email, password }));
      },
      async signOut() {
        return run(supabase.auth.signOut());
      },
      async currentUser() {
        return requireUser();
      },
    },

    async listMemberships() {
      const user = await requireUser();
      return run(
        supabase
          .from("organization_members")
          .select("organization_id, role, organizations(id, name)")
          .eq("user_id", user.id)
          .order("created_at", { ascending: true })
      );
    },

    async createOrganization(name) {
      await requireUser();
      const cleanName = String(name ?? "").trim();
      if (!cleanName || cleanName.length > 120) {
        throw new Error("Organization name must be 1–120 characters.");
      }
      return run(
        supabase.rpc("create_organization", { org_name: cleanName })
      );
    },

    async loadWorkspace(organizationId) {
      await requireUser();
      if (!organizationId) throw new Error("Choose an organization first.");
      const [technicians, workOrders] = await Promise.all([
        run(
          supabase
            .from("technicians")
            .select("*")
            .eq("organization_id", organizationId)
            .order("display_name", { ascending: true })
        ),
        run(
          supabase
            .from("work_orders")
            .select("*")
            .eq("organization_id", organizationId)
            .order("created_at", { ascending: false })
        ),
      ]);
      return { technicians, workOrders };
    },

    async createTechnician(organizationId, input) {
      const user = await requireUser();
      if (!organizationId) throw new Error("Choose an organization first.");
      return run(
        supabase
          .from("technicians")
          .insert({
            organization_id: organizationId,
            display_name: String(input.display_name ?? "").trim(),
            specialty: String(input.specialty ?? "HVAC Service").trim(),
            qualifications: String(input.qualifications ?? ""),
            shift_start: input.shift_start ?? "08:00",
            shift_end: input.shift_end ?? "17:00",
            is_available: input.is_available ?? true,
            user_id: input.user_id ?? null,
          })
          .select()
          .single()
      );
    },

    async updateTechnician(technicianId, patch) {
      await requireUser();
      const allowed = [
        "display_name",
        "specialty",
        "qualifications",
        "shift_start",
        "shift_end",
        "is_available",
        "user_id",
      ];
      const safePatch = Object.fromEntries(
        Object.entries(patch).filter(([key]) => allowed.includes(key))
      );
      return run(
        supabase
          .from("technicians")
          .update(safePatch)
          .eq("id", technicianId)
          .select()
          .single()
      );
    },

    async createWorkOrder(organizationId, input) {
      const user = await requireUser();
      if (!organizationId) throw new Error("Choose an organization first.");
      const payload = {
        organization_id: organizationId,
        customer_name: String(input.customer_name ?? "").trim(),
        service_address: String(input.service_address ?? "").trim(),
        callback_phone: String(input.callback_phone ?? ""),
        issue: String(input.issue ?? "").trim(),
        priority: input.priority ?? "Routine",
        status: input.status ?? "New",
        assigned_technician_id: input.assigned_technician_id ?? null,
        appointment_date: input.appointment_date || null,
        appointment_time: input.appointment_time || null,
        appointment_duration_minutes: input.appointment_duration_minutes ?? 60,
        after_hours_fee: input.after_hours_fee ?? 0,
        dispatch_notes: String(input.dispatch_notes ?? ""),
        created_by: user.id,
        updated_by: user.id,
      };
      return run(
        supabase.from("work_orders").insert(payload).select().single()
      );
    },

    async updateWorkOrder(workOrderId, patch) {
      const user = await requireUser();
      const allowed = [
        "customer_name",
        "service_address",
        "callback_phone",
        "issue",
        "priority",
        "status",
        "assigned_technician_id",
        "appointment_date",
        "appointment_time",
        "appointment_duration_minutes",
        "after_hours_fee",
        "dispatch_notes",
        "completed_at",
      ];
      const safePatch = Object.fromEntries(
        Object.entries(patch).filter(([key]) => allowed.includes(key))
      );
      safePatch.updated_by = user.id;
      return run(
        supabase
          .from("work_orders")
          .update(safePatch)
          .eq("id", workOrderId)
          .select()
          .single()
      );
    },

    async deleteWorkOrder(workOrderId, reason) {
      await requireUser();
      const cleanReason = String(reason ?? "").trim();
      if (!cleanReason || cleanReason.length > 1000) {
        throw new Error("A deletion reason of 1–1000 characters is required.");
      }
      return run(
        supabase.rpc("delete_work_order_with_reason", {
          target_work_order: workOrderId,
          delete_reason: cleanReason,
        })
      );
    },

    async loadAudit(organizationId) {
      await requireUser();
      if (!organizationId) throw new Error("Choose an organization first.");
      return run(
        supabase
          .from("work_order_audit")
          .select("*")
          .eq("organization_id", organizationId)
          .order("created_at", { ascending: false })
          .limit(500)
      );
    },
  };
}
