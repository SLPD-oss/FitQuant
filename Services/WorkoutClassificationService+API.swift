import Foundation

// MARK: - WorkoutClassificationService + API
// 【网络层 | 训练动作分类 API 扩展】
// 新增 async 方法优先请求后端 /api/workout/classify，
// 网络不可用时降级到本地的关键词映射逻辑。
// 调用方（TrainView）无需修改。

extension WorkoutClassificationService {

    /// 从后端获取动作分类，失败时降级到本地关键词匹配
    func detectAerobicSubTypeFromAPI(actionName: String) async -> AerobicSubType? {
        do {
            let req = WorkoutClassifyRequest(action_name: actionName)
            let resp: WorkoutClassifyResponse = try await APIClient.shared.post(
                "/api/workout/classify", body: req
            )
            if let subTypeStr = resp.aerobic_sub_type,
               let subType = AerobicSubType(rawValue: subTypeStr) {
                return subType
            }
            // 返回空表示非有氧训练（strength）
            return nil
        } catch {
            // API 不可用 → 降级到本地关键词匹配
            return detectAerobicSubType(actionName: actionName)
        }
    }

    /// 从后端获取高危手腕动作判定，失败时降级到本地
    func isHighRiskWristHiitActionFromAPI(actionName: String) async -> Bool {
        do {
            let req = WorkoutClassifyRequest(action_name: actionName)
            let resp: WorkoutClassifyResponse = try await APIClient.shared.post(
                "/api/workout/classify", body: req
            )
            return resp.is_high_risk_wrist
        } catch {
            return isHighRiskWristHiitAction(actionName: actionName)
        }
    }

    /// 从后端识别跑步机设备，失败时降级到本地关键词
    func isTreadmillDeviceFromAPI(actionName: String) async -> Bool {
        do {
            let req = WorkoutClassifyRequest(action_name: actionName)
            let resp: WorkoutClassifyResponse = try await APIClient.shared.post(
                "/api/workout/classify", body: req
            )
            return resp.common_equipment.contains("跑步机")
        } catch {
            return isTreadmillDevice(actionName: actionName)
        }
    }
}
